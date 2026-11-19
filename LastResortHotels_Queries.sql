-- SQLite reporting queries. H1 2026; Q5 snapshot June 30; Q7 forward booking example.

-- Q1. What share of installed sleeping-room inventory was occupied each month?
WITH RECURSIVE nights(stay_date) AS (
    VALUES ('2026-01-01')
    UNION ALL
    SELECT date(stay_date, '+1 day') FROM nights WHERE stay_date < '2026-06-30'
)
SELECT h.complexName, substr(n.stay_date, 1, 7) AS month,
       SUM(EXISTS (SELECT 1 FROM room_assignment a WHERE a.roomId = r.roomId
           AND a.assignmentStatus <> 'cancelled'
           AND date(a.actualCheckInAt) <= n.stay_date
           AND n.stay_date < date(COALESCE(a.actualCheckOutAt, '2026-07-01')))) AS occupied_room_nights,
       COUNT(*) AS inventory_room_nights,
       ROUND(100.0 * SUM(EXISTS (SELECT 1 FROM room_assignment a WHERE a.roomId = r.roomId
           AND a.assignmentStatus <> 'cancelled'
           AND date(a.actualCheckInAt) <= n.stay_date
           AND n.stay_date < date(COALESCE(a.actualCheckOutAt, '2026-07-01')))) / COUNT(*), 1) AS occupancy_pct
FROM nights n CROSS JOIN room r
JOIN floor f ON f.floorId = r.floorId
JOIN wing w ON w.wingId = f.wingId
JOIN building b ON b.buildingId = w.buildingId
JOIN hotel_complex h ON h.complexId = b.complexId
WHERE r.sleepingCapacity > 0
GROUP BY h.complexId, month
ORDER BY month, h.complexName;

-- Q2. Which services generated posted charges each month, and how much?
SELECT substr(c.incurredAt, 1, 7) AS month, s.serviceCategory,
       COUNT(*) AS charge_count, ROUND(SUM(c.quantity * c.unitPrice), 2) AS posted_usd
FROM charge c JOIN service s ON s.serviceId = c.serviceId
WHERE c.chargeStatus = 'posted'
  AND c.incurredAt >= '2026-01-01' AND c.incurredAt < '2026-07-01'
GROUP BY month, s.serviceCategory
ORDER BY month, posted_usd DESC;

-- Q3. How did cancellation rates differ for overnight bookings with and without a required deposit?
SELECT (r.depositAmount > 0) AS depositRequired, COUNT(*) AS bookings,
       SUM(r.reservationStatus = 'cancelled') AS cancellations,
       ROUND(100.0 * SUM(r.reservationStatus = 'cancelled') / COUNT(*), 1) AS cancellation_pct
FROM reservation r
WHERE r.startAt >= '2026-01-01' AND r.startAt < '2026-07-01'
  AND EXISTS (SELECT 1 FROM reservation_requirement q
              WHERE q.reservationId = r.reservationId AND q.requirementType = 'sleeping')
GROUP BY (r.depositAmount > 0)
ORDER BY depositRequired;

-- Q4. Which hosts consistently overestimated or underestimated event attendance?
WITH headcount AS (
    SELECT e.eventId, e.hostPartyId, e.estimatedAttendance, COUNT(a.personId) AS recorded
    FROM event e LEFT JOIN event_attendee a ON a.eventId = e.eventId
    WHERE e.startAt >= '2026-01-01' AND e.startAt < '2026-07-01'
    GROUP BY e.eventId, e.hostPartyId, e.estimatedAttendance
)
SELECT COALESCE(o.organizationName, p.firstName || ' ' || p.lastName) AS host,
       COUNT(*) AS events, SUM(h.estimatedAttendance) AS expected,
       SUM(h.recorded) AS recorded, SUM(h.recorded > h.estimatedAttendance) AS above_estimate,
       SUM(h.recorded < h.estimatedAttendance) AS below_estimate,
       ROUND(AVG(h.recorded - h.estimatedAttendance), 1) AS mean_error_people
FROM headcount h
LEFT JOIN organization o ON o.partyId = h.hostPartyId
LEFT JOIN person p ON p.partyId = h.hostPartyId
GROUP BY h.hostPartyId, host
ORDER BY mean_error_people DESC, host;

-- Q5. Which billing parties had the most overdue money at the close of June 30?
WITH billed AS (
    SELECT invoiceId, SUM(allocatedAmount) AS billed_usd
    FROM invoice_charge GROUP BY invoiceId
), paid AS (
    SELECT invoiceId, SUM(amount) AS paid_usd FROM payment
    WHERE paidAt < '2026-07-01' GROUP BY invoiceId
), overdue AS (
    SELECT i.responsiblePartyId, i.invoiceId,
           ROUND(b.billed_usd - COALESCE(p.paid_usd, 0), 2) AS balance
    FROM invoice i JOIN billed b ON b.invoiceId = i.invoiceId
    LEFT JOIN paid p ON p.invoiceId = i.invoiceId
    WHERE i.dueAt < '2026-07-01' AND i.issuedAt < '2026-07-01'
      AND i.invoiceStatus NOT IN ('void', 'cancelled')
)
SELECT COALESCE(o.organizationName, p.firstName || ' ' || p.lastName) AS billing_party,
       COUNT(*) AS overdue_invoices, ROUND(SUM(d.balance), 2) AS overdue_usd
FROM overdue d
LEFT JOIN organization o ON o.partyId = d.responsiblePartyId
LEFT JOIN person p ON p.partyId = d.responsiblePartyId
WHERE d.balance > 0
GROUP BY d.responsiblePartyId, billing_party
ORDER BY overdue_usd DESC, billing_party LIMIT 10;

-- Q6. Which wings take longest to return rooms to service after departure cleaning?
WITH changes AS (
    SELECT roomId, roomStatus, effectiveAt,
           LEAD(roomStatus) OVER history AS next_status,
           LEAD(effectiveAt) OVER history AS next_time
    FROM room_status_history
    WINDOW history AS (PARTITION BY roomId ORDER BY effectiveAt)
)
SELECT h.complexName, b.buildingName, w.wingCode, COUNT(*) AS completed_cleans,
       ROUND(AVG((julianday(c.next_time) - julianday(c.effectiveAt)) * 1440), 1) AS avg_minutes
FROM changes c JOIN room r ON r.roomId = c.roomId
JOIN floor f ON f.floorId = r.floorId JOIN wing w ON w.wingId = f.wingId
JOIN building b ON b.buildingId = w.buildingId
JOIN hotel_complex h ON h.complexId = b.complexId
WHERE c.roomStatus = 'cleaning' AND c.next_status = 'ready'
  AND c.effectiveAt >= '2026-01-01' AND c.next_time < '2026-07-01'
GROUP BY h.complexId, b.buildingId, w.wingId
ORDER BY avg_minutes DESC, w.wingSequence;

-- Q7. Which eligible rooms should the desk offer for the earliest unassigned Harbor House request?
WITH request AS (
    SELECT q.*, r.startAt, r.endAt FROM reservation_requirement q
    JOIN reservation r ON r.reservationId = q.reservationId
    WHERE r.reservationStatus = 'confirmed' AND r.preferenceNotes = 'Harbor House requested'
      AND q.requirementType = 'sleeping' AND q.roomQuantity = 1
      AND NOT EXISTS (SELECT 1 FROM room_assignment a WHERE a.requirementId = q.requirementId
                      AND a.assignmentStatus <> 'cancelled')
    ORDER BY r.startAt, q.requirementId LIMIT 1
)
SELECT q.reservationId, b.buildingName, w.wingCode, w.wingSequence,
       r.roomNumber, r.roomCategory, r.baseDailyRate
FROM request q CROSS JOIN room r
JOIN floor f ON f.floorId = r.floorId JOIN wing w ON w.wingId = f.wingId
JOIN building b ON b.buildingId = w.buildingId
WHERE b.complexId = 1 AND r.sleepingCapacity > 0
  AND r.sleepingCapacity >= MAX(COALESCE(q.minimumSleepingCapacity, 0), COALESCE(q.guestCount, 0))
  AND (q.accessibleRequired = 0 OR w.accessible = 1)
  AND (q.smokingPreference IS NULL OR q.smokingPreference = 'any'
       OR r.canSmoke = (q.smokingPreference = 'smoking'))
  AND NOT EXISTS (
      SELECT 1 FROM requirement_bed need
      WHERE need.requirementId = q.requirementId AND NOT EXISTS (
          SELECT 1 FROM room_bed rb WHERE rb.roomId = r.roomId
            AND rb.bedTypeId = need.bedTypeId AND rb.quantity >= need.minimumQuantity))
  AND NOT EXISTS (
      SELECT 1 FROM room_assignment a WHERE a.roomId = r.roomId AND a.assignmentStatus <> 'cancelled'
        AND a.scheduledStartAt < q.endAt AND a.scheduledEndAt > q.startAt)
  AND NOT EXISTS (
      SELECT 1 FROM event_room er JOIN time_slot ts ON ts.timeSlotId = er.timeSlotId
      WHERE er.roomId = r.roomId AND datetime(er.usageDate || ' ' || ts.startTime) < q.endAt
        AND datetime(er.usageDate || ' ' || ts.endTime) > q.startAt)
  AND (SELECT s.roomStatus FROM room_status_history s WHERE s.roomId = r.roomId
       AND s.effectiveAt <= q.startAt ORDER BY s.effectiveAt DESC LIMIT 1) = 'ready'
  AND NOT EXISTS (
      SELECT 1 FROM room_status_history s WHERE s.roomId = r.roomId
        AND s.effectiveAt > q.startAt AND s.effectiveAt < q.endAt AND s.roomStatus <> 'ready')
ORDER BY w.wingSequence, CAST(r.roomNumber AS INTEGER) LIMIT 5;

-- Q8. Which meeting periods are used most, and how often are they complimentary?
SELECT t.slotName, COUNT(er.eventRoomId) AS booked_slots,
       COUNT(DISTINCT er.eventId) AS events_served,
       SUM(CASE WHEN er.agreedRate = 0 THEN 1 ELSE 0 END) AS free_slots,
       COALESCE(SUM(er.agreedRate), 0) AS agreed_room_fees_usd
FROM time_slot t LEFT JOIN event_room er ON er.timeSlotId = t.timeSlotId
  AND er.usageDate >= '2026-01-01' AND er.usageDate < '2026-07-01'
GROUP BY t.timeSlotId, t.slotName, t.startTime
ORDER BY booked_slots DESC, t.startTime;
