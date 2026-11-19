# Implemented schema

Tables use snake_case; fields use camelCase. This is the Milestone 2 schema, superseding the archived Milestone 1 ERD labels.

## hotel_complex

```sql
CREATE TABLE hotel_complex (
    complexId INTEGER PRIMARY KEY,
    complexName TEXT NOT NULL,
    addressLine1 TEXT NOT NULL,
    addressLine2 TEXT,
    city TEXT NOT NULL,
    stateRegion TEXT NOT NULL,
    postalCode TEXT NOT NULL,
    country TEXT NOT NULL,
    UNIQUE (complexName)
);
```

## building

```sql
CREATE TABLE building (
    buildingId INTEGER PRIMARY KEY,
    complexId INTEGER NOT NULL REFERENCES hotel_complex(complexId),
    buildingName TEXT NOT NULL,
    UNIQUE (complexId, buildingName)
);
```

## wing

```sql
CREATE TABLE wing (
    wingId INTEGER PRIMARY KEY,
    buildingId INTEGER NOT NULL REFERENCES building(buildingId),
    wingCode TEXT NOT NULL,
    wingSequence INTEGER NOT NULL CHECK (wingSequence > 0),
    accessible INTEGER NOT NULL CHECK (accessible IN (0, 1)),
    poolProximityNote TEXT,
    parkingProximityNote TEXT,
    UNIQUE (buildingId, wingCode),
    UNIQUE (wingSequence)
);
```

## floor

```sql
CREATE TABLE floor (
    floorId INTEGER PRIMARY KEY,
    wingId INTEGER NOT NULL REFERENCES wing(wingId),
    floorNumber INTEGER NOT NULL,
    smokingPolicy TEXT NOT NULL,
    UNIQUE (wingId, floorNumber),
    CHECK (smokingPolicy IN ('nonsmoking','mixed')),
    CHECK (floorNumber BETWEEN 1 AND 99)
);
```

## room

```sql
CREATE TABLE room (
    roomId INTEGER PRIMARY KEY,
    floorId INTEGER NOT NULL REFERENCES floor(floorId),
    roomNumber TEXT NOT NULL,
    roomName TEXT,
    roomCategory TEXT NOT NULL,
    baseDailyRate NUMERIC NOT NULL CHECK (baseDailyRate >= 0),
    sleepingCapacity INTEGER NOT NULL CHECK (sleepingCapacity >= 0),
    seatingCapacity INTEGER NOT NULL CHECK (seatingCapacity >= 0),
    hasToilet INTEGER NOT NULL CHECK (hasToilet IN (0, 1)),
    hasBath INTEGER NOT NULL CHECK (hasBath IN (0, 1)),
    hasPhone INTEGER NOT NULL CHECK (hasPhone IN (0, 1)),
    hasTv INTEGER NOT NULL CHECK (hasTv IN (0, 1)),
    outdoorSpace INTEGER NOT NULL CHECK (outdoorSpace IN (0, 1)),
    canSmoke INTEGER NOT NULL CHECK (canSmoke IN (0, 1)),
    UNIQUE (floorId, roomNumber),
    CHECK (sleepingCapacity > 0 OR seatingCapacity > 0),
    CHECK (sleepingCapacity = 0 OR hasToilet = 1)
);
```

## bed_type

```sql
CREATE TABLE bed_type (
    bedTypeId INTEGER PRIMARY KEY,
    bedSize TEXT NOT NULL,
    bedStyle TEXT NOT NULL,
    extraLong INTEGER NOT NULL CHECK (extraLong IN (0, 1)),
    sleepsPeople INTEGER NOT NULL CHECK (sleepsPeople > 0),
    UNIQUE (bedSize, bedStyle, extraLong)
);
```

## room_bed

```sql
CREATE TABLE room_bed (
    roomBedId INTEGER PRIMARY KEY,
    roomId INTEGER NOT NULL REFERENCES room(roomId),
    bedTypeId INTEGER NOT NULL REFERENCES bed_type(bedTypeId),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    UNIQUE (roomId, bedTypeId)
);
```

## room_connection

```sql
CREATE TABLE room_connection (
    connectionId INTEGER PRIMARY KEY,
    roomIdA INTEGER NOT NULL REFERENCES room(roomId),
    roomIdB INTEGER NOT NULL REFERENCES room(roomId),
    connectionType TEXT NOT NULL,
    connectionNote TEXT,
    UNIQUE (roomIdA, roomIdB),
    CHECK (roomIdA < roomIdB)
);
```

## facility

```sql
CREATE TABLE facility (
    facilityId INTEGER PRIMARY KEY,
    complexId INTEGER NOT NULL REFERENCES hotel_complex(complexId),
    facilityName TEXT NOT NULL,
    facilityType TEXT NOT NULL,
    locationDescription TEXT NOT NULL,
    UNIQUE (complexId, facilityName)
);
```

## party

```sql
CREATE TABLE party (
    partyId INTEGER PRIMARY KEY,
    partyType TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    CHECK (partyType IN ('person','organization'))
);
```

## person

```sql
CREATE TABLE person (
    personId INTEGER PRIMARY KEY,
    partyId INTEGER NOT NULL REFERENCES party(partyId),
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    confidentialityFlag INTEGER NOT NULL CHECK (confidentialityFlag IN (0, 1)),
    UNIQUE (partyId)
);
```

## organization

```sql
CREATE TABLE organization (
    organizationId INTEGER PRIMARY KEY,
    partyId INTEGER NOT NULL REFERENCES party(partyId),
    organizationName TEXT NOT NULL,
    UNIQUE (partyId)
);
```

## organization_person

```sql
CREATE TABLE organization_person (
    organizationPersonId INTEGER PRIMARY KEY,
    organizationId INTEGER NOT NULL REFERENCES organization(organizationId),
    personId INTEGER NOT NULL REFERENCES person(personId),
    affiliationRole TEXT NOT NULL,
    authorizedRepresentative INTEGER NOT NULL CHECK (authorizedRepresentative IN (0, 1)),
    UNIQUE (organizationId, personId)
);
```

## staff

```sql
CREATE TABLE staff (
    staffId INTEGER PRIMARY KEY,
    personId INTEGER NOT NULL REFERENCES person(personId),
    jobTitle TEXT NOT NULL,
    employmentStatus TEXT NOT NULL,
    UNIQUE (personId)
);
```

## reservation

```sql
CREATE TABLE reservation (
    reservationId INTEGER PRIMARY KEY,
    bookingPartyId INTEGER NOT NULL REFERENCES party(partyId),
    createdAt TEXT NOT NULL,
    startAt TEXT NOT NULL,
    endAt TEXT NOT NULL,
    reservationStatus TEXT NOT NULL,
    depositAmount NUMERIC NOT NULL CHECK (depositAmount >= 0),
    preferenceNotes TEXT,
    CHECK (endAt > startAt),
    CHECK (createdAt <= startAt)
);
```

## reservation_requirement

```sql
CREATE TABLE reservation_requirement (
    requirementId INTEGER PRIMARY KEY,
    reservationId INTEGER NOT NULL REFERENCES reservation(reservationId),
    requirementType TEXT NOT NULL,
    roomQuantity INTEGER NOT NULL CHECK (roomQuantity > 0),
    guestCount INTEGER CHECK (guestCount >= 0),
    meetingAttendance INTEGER CHECK (meetingAttendance >= 0),
    smokingPreference TEXT,
    accessibleRequired INTEGER NOT NULL CHECK (accessibleRequired IN (0, 1)),
    minimumSleepingCapacity INTEGER CHECK (minimumSleepingCapacity >= 0),
    minimumSeatingCapacity INTEGER CHECK (minimumSeatingCapacity >= 0),
    proximityNotes TEXT
);
```

## requirement_bed

```sql
CREATE TABLE requirement_bed (
    requirementBedId INTEGER PRIMARY KEY,
    requirementId INTEGER NOT NULL REFERENCES reservation_requirement(requirementId),
    bedTypeId INTEGER NOT NULL REFERENCES bed_type(bedTypeId),
    minimumQuantity INTEGER NOT NULL CHECK (minimumQuantity > 0),
    UNIQUE (requirementId, bedTypeId)
);
```

## room_assignment

```sql
CREATE TABLE room_assignment (
    assignmentId INTEGER PRIMARY KEY,
    requirementId INTEGER NOT NULL REFERENCES reservation_requirement(requirementId),
    roomId INTEGER NOT NULL REFERENCES room(roomId),
    scheduledStartAt TEXT NOT NULL,
    scheduledEndAt TEXT NOT NULL,
    actualCheckInAt TEXT,
    actualCheckOutAt TEXT,
    assignmentStatus TEXT NOT NULL,
    agreedRate NUMERIC NOT NULL CHECK (agreedRate >= 0),
    CHECK (scheduledEndAt > scheduledStartAt),
    CHECK (actualCheckOutAt IS NULL OR (actualCheckInAt IS NOT NULL AND actualCheckOutAt > actualCheckInAt))
);
```

## assignment_guest

```sql
CREATE TABLE assignment_guest (
    assignmentGuestId INTEGER PRIMARY KEY,
    assignmentId INTEGER NOT NULL REFERENCES room_assignment(assignmentId),
    personId INTEGER NOT NULL REFERENCES person(personId),
    primaryGuest INTEGER NOT NULL CHECK (primaryGuest IN (0, 1)),
    UNIQUE (assignmentId, personId)
);
```

## time_slot

```sql
CREATE TABLE time_slot (
    timeSlotId INTEGER PRIMARY KEY,
    slotName TEXT NOT NULL,
    startTime TEXT NOT NULL,
    endTime TEXT NOT NULL,
    UNIQUE (slotName),
    CHECK (endTime > startTime)
);
```

## event

```sql
CREATE TABLE event (
    eventId INTEGER PRIMARY KEY,
    reservationId INTEGER NOT NULL REFERENCES reservation(reservationId),
    hostPartyId INTEGER NOT NULL REFERENCES party(partyId),
    eventName TEXT NOT NULL,
    startAt TEXT NOT NULL,
    endAt TEXT NOT NULL,
    estimatedAttendance INTEGER NOT NULL CHECK (estimatedAttendance >= 0),
    estimatedHotelGuests INTEGER NOT NULL CHECK (estimatedHotelGuests >= 0),
    CHECK (endAt > startAt),
    CHECK (estimatedHotelGuests <= estimatedAttendance)
);
```

## event_room

```sql
CREATE TABLE event_room (
    eventRoomId INTEGER PRIMARY KEY,
    eventId INTEGER NOT NULL REFERENCES event(eventId),
    roomId INTEGER NOT NULL REFERENCES room(roomId),
    timeSlotId INTEGER NOT NULL REFERENCES time_slot(timeSlotId),
    usageDate TEXT NOT NULL,
    eatingUse INTEGER NOT NULL CHECK (eatingUse IN (0, 1)),
    agreedRate NUMERIC NOT NULL CHECK (agreedRate >= 0),
    UNIQUE (roomId, usageDate, timeSlotId)
);
```

## event_attendee

```sql
CREATE TABLE event_attendee (
    eventAttendeeId INTEGER PRIMARY KEY,
    eventId INTEGER NOT NULL REFERENCES event(eventId),
    personId INTEGER NOT NULL REFERENCES person(personId),
    attendeeRole TEXT NOT NULL,
    UNIQUE (eventId, personId)
);
```

## service

```sql
CREATE TABLE service (
    serviceId INTEGER PRIMARY KEY,
    serviceName TEXT NOT NULL,
    serviceCategory TEXT NOT NULL,
    unitDescription TEXT NOT NULL,
    defaultUnitPrice NUMERIC NOT NULL CHECK (defaultUnitPrice >= 0),
    UNIQUE (serviceName)
);
```

## charge

```sql
CREATE TABLE charge (
    chargeId INTEGER PRIMARY KEY,
    reservationId INTEGER REFERENCES reservation(reservationId),
    eventId INTEGER REFERENCES event(eventId),
    assignmentId INTEGER REFERENCES room_assignment(assignmentId),
    serviceId INTEGER NOT NULL REFERENCES service(serviceId),
    facilityId INTEGER REFERENCES facility(facilityId),
    incurredAt TEXT NOT NULL,
    quantity NUMERIC NOT NULL CHECK (quantity > 0),
    unitPrice NUMERIC NOT NULL CHECK (unitPrice >= 0),
    chargeStatus TEXT NOT NULL,
    chargeDescription TEXT NOT NULL,
    CHECK ((reservationId IS NOT NULL) + (assignmentId IS NOT NULL) + (eventId IS NOT NULL) = 1)
);
```

## invoice

```sql
CREATE TABLE invoice (
    invoiceId INTEGER PRIMARY KEY,
    responsiblePartyId INTEGER NOT NULL REFERENCES party(partyId),
    reservationId INTEGER NOT NULL REFERENCES reservation(reservationId),
    issuedAt TEXT NOT NULL,
    dueAt TEXT NOT NULL,
    invoiceStatus TEXT NOT NULL,
    CHECK (dueAt >= issuedAt)
);
```

## invoice_charge

```sql
CREATE TABLE invoice_charge (
    invoiceChargeId INTEGER PRIMARY KEY,
    invoiceId INTEGER NOT NULL REFERENCES invoice(invoiceId),
    chargeId INTEGER NOT NULL REFERENCES charge(chargeId),
    allocatedAmount NUMERIC NOT NULL CHECK (allocatedAmount > 0),
    UNIQUE (invoiceId, chargeId)
);
```

## payment

```sql
CREATE TABLE payment (
    paymentId INTEGER PRIMARY KEY,
    invoiceId INTEGER NOT NULL REFERENCES invoice(invoiceId),
    paidAt TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    paymentMethod TEXT NOT NULL,
    referenceCode TEXT NOT NULL,
    UNIQUE (referenceCode)
);
```

## room_status_history

```sql
CREATE TABLE room_status_history (
    roomStatusId INTEGER PRIMARY KEY,
    roomId INTEGER NOT NULL REFERENCES room(roomId),
    changedByStaffId INTEGER NOT NULL REFERENCES staff(staffId),
    roomStatus TEXT NOT NULL,
    effectiveAt TEXT NOT NULL,
    statusNote TEXT,
    UNIQUE (roomId, effectiveAt)
);
```

## key_card

```sql
CREATE TABLE key_card (
    cardId INTEGER PRIMARY KEY,
    assignedPersonId INTEGER NOT NULL REFERENCES person(personId),
    cardNumber TEXT NOT NULL,
    pinHash TEXT NOT NULL,
    issuedAt TEXT NOT NULL,
    deactivatedAt TEXT,
    UNIQUE (cardNumber),
    CHECK (deactivatedAt IS NULL OR deactivatedAt >= issuedAt)
);
```

## card_reader

```sql
CREATE TABLE card_reader (
    readerId INTEGER PRIMARY KEY,
    roomId INTEGER REFERENCES room(roomId),
    facilityId INTEGER REFERENCES facility(facilityId),
    readerName TEXT NOT NULL,
    locationDescription TEXT NOT NULL,
    CHECK ((roomId IS NOT NULL) + (facilityId IS NOT NULL) = 1)
);
```

## access_log

```sql
CREATE TABLE access_log (
    accessLogId INTEGER PRIMARY KEY,
    cardId INTEGER NOT NULL REFERENCES key_card(cardId),
    readerId INTEGER NOT NULL REFERENCES card_reader(readerId),
    swipedAt TEXT NOT NULL,
    direction TEXT NOT NULL,
    accessGranted INTEGER NOT NULL CHECK (accessGranted IN (0, 1)),
    CHECK (direction IN ('in','out'))
);
```

## guest_message

```sql
CREATE TABLE guest_message (
    messageId INTEGER PRIMARY KEY,
    recipientPersonId INTEGER NOT NULL REFERENCES person(personId),
    recordedByStaffId INTEGER NOT NULL REFERENCES staff(staffId),
    recordedAt TEXT NOT NULL,
    availableUntil TEXT,
    messageText TEXT NOT NULL,
    confidential INTEGER NOT NULL CHECK (confidential IN (0, 1)),
    CHECK (availableUntil IS NULL OR availableUntil >= recordedAt)
);
```
