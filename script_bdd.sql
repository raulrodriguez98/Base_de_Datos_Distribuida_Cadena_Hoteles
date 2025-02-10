CREATE TABLE Empleado(
	codEmpleado NUMBER PRIMARY KEY,
	DNI VARCHAR2(8) UNIQUE NOT NULL,
    nombre VARCHAR2(100) NOT NULL,
	direccion VARCHAR2(100),
	telefono VARCHAR2(6),
	fechaContrato DATE NOT NULL,
	salario NUMBER NOT NULL
);

CREATE TABLE Hotel (
    codHotel NUMBER PRIMARY KEY,
    nombre VARCHAR2(100),
    numHabSencillas INTEGER NOT NULL,
    numHabDobles INTEGER NOT NULL,
    ciudad VARCHAR2(50) NOT NULL,
    provincia VARCHAR2(50) NOT NULL,
    director NUMBER UNIQUE,
    FOREIGN KEY (director) REFERENCES Empleado(codEmpleado)
);

CREATE TABLE Cliente(
	codCliente NUMBER PRIMARY KEY,
	DNI VARCHAR2(8) UNIQUE NOT NULL,
	nombre VARCHAR2(50),
	telefono VARCHAR2(6)
);

CREATE TABLE Contrata(
    codHotel NUMBER,
    codEmpleado NUMBER,
    fechaInicio DATE NOT NULL,
    fechaFin DATE,
    PRIMARY KEY (codHotel, codEmpleado, fechaInicio),
    FOREIGN KEY (codHotel) REFERENCES Hotel(codHotel),
    FOREIGN KEY (codEmpleado) REFERENCES Empleado(codEmpleado)
);

CREATE TABLE Articulo(
	codArticulo NUMBER PRIMARY KEY,
	nombre VARCHAR2(50) NOT NULL,
	tipo CHAR(1) CHECK (tipo IN ('A', 'B', 'C', 'D'))
);

CREATE TABLE Reserva(
    codCliente NUMBER,
    codHotel NUMBER,
    fechaEntrada DATE NOT NULL,
    fechaSalida DATE NOT NULL,
    tipoHab VARCHAR(10) NOT NULL,
    precio NUMBER NOT NULL,
    PRIMARY KEY (codCliente, codHotel, fechaEntrada),
    FOREIGN KEY (codCliente) REFERENCES Cliente(codCliente),
    FOREIGN KEY (codHotel) REFERENCES Hotel(codHotel),
    CHECK (tipoHab IN ('Sencilla', 'Doble')),
    CHECK (fechaSalida > fechaEntrada)
);

CREATE TABLE Proveedor(
	codProv NUMBER PRIMARY KEY,
	nombre VARCHAR2(100),
	ciudad VARCHAR2(50) CHECK (ciudad IN ('Granada', 'Sevilla'))
);


CREATE TABLE Suministra(
    codProv NUMBER,
    codHotel NUMBER,
    codArticulo NUMBER,
    cantidad NUMBER DEFAULT 0,
    precio NUMBER NOT NULL,
    fecha DATE NOT NULL,
    PRIMARY KEY (codProv, codHotel, codArticulo, fecha),
    FOREIGN KEY (codProv, codArticulo) REFERENCES Tiene(codProv, codArticulo),
    FOREIGN KEY (codHotel) REFERENCES Hotel(codHotel),
    CHECK (cantidad >= 0),
    CHECK (precio > 0)
);

// TRIGGERS //

DROP TRIGGER comprobar_capacidad_hotel;

// Restricción de Integridad 4 - Capacidad del Hotel
// Restricción de Integridad 5 - Fecha de entrada de cliente no puede ser posterior a la de salida
// Restricción de Integridad 6 - Un cliente no puede hacer una reserva en distintos hoteles para la misma fecha
CREATE OR REPLACE TRIGGER comprobar_reserva
BEFORE INSERT OR UPDATE ON Reserva
FOR EACH ROW
DECLARE
    sencillasReservadas INTEGER;
    doblesReservadas INTEGER;
    numSencillasDisponibles INTEGER;
    numDoblesDisponibles INTEGER;
    conflictCount INTEGER;
BEGIN
    -- Contar las habitaciones sencillas ya reservadas en el rango de fechas
    SELECT COUNT(*)
    INTO sencillasReservadas
    FROM ReservaView r
    WHERE r.codHotel = :NEW.codHotel
      AND r.tipoHab = 'Sencilla'
      AND r.fechaEntrada < :NEW.fechaSalida
      AND r.fechaSalida > :NEW.fechaEntrada;

    -- Contar las habitaciones dobles ya reservadas en el rango de fechas
    SELECT COUNT(*)
    INTO doblesReservadas
    FROM ReservaView r
    WHERE r.codHotel = :NEW.codHotel
      AND r.tipoHab = 'Doble'
      AND r.fechaEntrada < :NEW.fechaSalida
      AND r.fechaSalida > :NEW.fechaEntrada;

    -- Obtener la capacidad total de habitaciones sencillas y dobles
    SELECT numHabSencillas, numHabDobles
    INTO numSencillasDisponibles, numDoblesDisponibles
    FROM HotelView h
    WHERE h.codHotel = :NEW.codHotel;

    -- Obtener el número de reservas que tenga el cliente en cualquier hotel
    SELECT COUNT(*) INTO conflictCount
    FROM ReservaView r
    WHERE r.codCliente = :NEW.codCliente AND
          ((:NEW.fechaEntrada BETWEEN r.fechaEntrada AND r.fechaSalida) OR
           (:NEW.fechaSalida BETWEEN r.fechaEntrada AND r.fechaSalida)) AND
          r.codHotel <> :NEW.codHotel;
          
    -- Verificar si excede la capacidad para habitaciones sencillas
    IF :NEW.tipoHab = 'Sencilla' AND sencillasReservadas >= numSencillasDisponibles THEN
        RAISE_APPLICATION_ERROR(-20001, 'No hay habitaciones sencillas disponibles en el hotel.');
    END IF;

    -- Verificar si excede la capacidad para habitaciones dobles
    IF :NEW.tipoHab = 'Doble' AND doblesReservadas >= numDoblesDisponibles THEN
        RAISE_APPLICATION_ERROR(-20002, 'No hay habitaciones dobles disponibles en el hotel.');
    END IF;
    
    -- Verificar si excede la capacidad para habitaciones dobles
    IF :NEW.fechaEntrada >= :NEW.fechaSalida THEN
        RAISE_APPLICATION_ERROR(-20003, 'La fecha de entrada debe ser anterior a la de salida.');
    END IF;
    
    -- Verificar que no tenga una reserva en esa fecha en otro hotel
    IF conflictCount > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'El cliente ya tiene una reserva en otro hotel para las mismas fechas.');
    END IF;
END;
/

//Prueba trigger
// Hotel
INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (1, 'Hotel Prueba', 2, 1, 'Granada', 'Granada', NULL);

INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (2, 'Hotel Secundario', 1, 1, 'Sevilla', 'Sevilla', NULL);


// Clientes
INSERT INTO Cliente (codCliente, DNI, nombre, telefono)
VALUES (1, '12345678', 'Cliente Uno', '123456');

INSERT INTO Cliente (codCliente, DNI, nombre, telefono)
VALUES (2, '87654321', 'Cliente Dos', '654321');


// Reservas
INSERT INTO Reserva (codCliente, codHotel, fechaEntrada, fechaSalida, tipoHab, precio)
VALUES (1, 1, TO_DATE('2024-06-01', 'YYYY-MM-DD'), TO_DATE('2024-06-03', 'YYYY-MM-DD'), 'Sencilla', 100);

INSERT INTO Reserva (codCliente, codHotel, fechaEntrada, fechaSalida, tipoHab, precio)
VALUES (2, 1, TO_DATE('2024-07-01', 'YYYY-MM-DD'), TO_DATE('2024-07-03', 'YYYY-MM-DD'), 'Doble', 150);

INSERT INTO Reserva (codCliente, codHotel, fechaEntrada, fechaSalida, tipoHab, precio)
VALUES (2, 1, TO_DATE('2024-06-01', 'YYYY-MM-DD'), TO_DATE('2024-06-03', 'YYYY-MM-DD'), 'Sencilla', 100);

INSERT INTO Reserva (codCliente, codHotel, fechaEntrada, fechaSalida, tipoHab, precio)
VALUES (1, 1, TO_DATE('2024-07-01', 'YYYY-MM-DD'), TO_DATE('2024-07-03', 'YYYY-MM-DD'), 'Doble', 100);

INSERT INTO Reserva (codCliente, codHotel, fechaEntrada, fechaSalida, tipoHab, precio)
VALUES (1, 1, TO_DATE('2024-06-03', 'YYYY-MM-DD'), TO_DATE('2024-07-02', 'YYYY-MM-DD'), 'Doble', 100);

INSERT INTO Reserva (codCliente, codHotel, fechaEntrada, fechaSalida, tipoHab, precio)
VALUES (1, 2, TO_DATE('2024-06-04', 'YYYY-MM-DD'), TO_DATE('2024-06-09', 'YYYY-MM-DD'), 'Doble', 100);


// Código para eliminar elementos
-- Eliminar todas las reservas
DELETE FROM Reserva WHERE codHotel IN (1, 2);

-- Eliminar los clientes de prueba
DELETE FROM Cliente WHERE codCliente IN (1, 2, 3);

-- Eliminar el hotel de prueba
DELETE FROM Hotel WHERE codHotel IN (1, 2);


// Restricción de Integridad 10
// El salario de un empleado no puede disminuir
CREATE OR REPLACE TRIGGER prevenir_reduccion_salario
BEFORE UPDATE ON Empleado
FOR EACH ROW
BEGIN
    IF :NEW.salario < :OLD.salario THEN
        RAISE_APPLICATION_ERROR(-20005, 'El salario de un empleado no puede disminuir.');
    END IF;
END;
/


//Prueba trigger 10
INSERT INTO Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
VALUES (1, '12345678', 'Empleado Uno', 'Calle Falsa 123', '123456', TO_DATE('2023-01-01', 'YYYY-MM-DD'), 2000);

UPDATE Empleado
SET salario = 2500
WHERE codEmpleado = 1;

UPDATE Empleado
SET salario = 1800
WHERE codEmpleado = 1;

UPDATE Empleado
SET salario = 2500
WHERE codEmpleado = 1;


UPDATE Empleado
SET direccion = 'Calle Nueva 456'
WHERE codEmpleado = 1;

DELETE FROM Empleado WHERE codEmpleado = 1;

DROP TRIGGER validar_fecha_contrato;
// Restricción de Integridad 11
// Fecha de inicio de un empleado debe ser igual o posterior que la de inicio de contrato
// Restricción de Integridad 12
// La fecha de inicio de un empleado será igual o posterior a la de fin en el hotel en el que estaba asignado anteriormente
CREATE OR REPLACE TRIGGER validar_fecha_contrato
BEFORE INSERT OR UPDATE ON Contrata FOR EACH ROW
DECLARE
    comienzoContrato DATE;
    fechaFinAnterior DATE;
BEGIN
    SELECT fechaContrato INTO comienzoContrato
    FROM EmpleadoView e
    WHERE e.codEmpleado = :NEW.codEmpleado;

    SELECT MAX(fechaFin) INTO fechaFinAnterior
    FROM ContrataView c
    WHERE c.codEmpleado = :NEW.codEmpleado AND codHotel <> :NEW.codHotel;
    
    IF :NEW.fechaInicio < comienzoContrato THEN
        RAISE_APPLICATION_ERROR(-20006, 'La fecha de inicio en el hotel debe ser igual o posterior a la del contrato.');
    END IF;
    
    IF fechaFinAnterior IS NOT NULL AND :NEW.fechaInicio < fechaFinAnterior THEN
        RAISE_APPLICATION_ERROR(-20007, 'La fecha de inicio debe ser igual o posterior a la última fecha de fin en otro hotel.');
    END IF;
END;
/

// Pruebas triggers 11 y 12
INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (1, 'Hotel Prueba', 10, 10, 'Granada', 'Granada', NULL);

INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (2, 'Hotel Secundario', 20, 20, 'Sevilla', 'Sevilla', NULL);


INSERT INTO Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
VALUES (1, '12345678', 'Empleado Uno', 'Calle Falsa 123', '123456', TO_DATE('2023-01-01', 'YYYY-MM-DD'), 2000);

INSERT INTO Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
VALUES (2, '87654321', 'Empleado Dos', 'Calle Nueva 456', '654321', TO_DATE('2023-05-01', 'YYYY-MM-DD'), 2500);


// Caso 1: Fecha de Inicio Igual o Posterior a la Fecha de Contrato (válido)
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (1, 1, TO_DATE('2023-02-01', 'YYYY-MM-DD'), TO_DATE('2023-06-01', 'YYYY-MM-DD'));

// Caso 2: Fecha de Inicio Anterior a la Fecha de Contrato (inválido)
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (1, 1, TO_DATE('2022-12-01', 'YYYY-MM-DD'), TO_DATE('2023-06-01', 'YYYY-MM-DD'));

//Caso 3: Fecha de Inicio Posterior a la Última Fecha de Fin en Otro Hotel (válido)
-- Primera asignación
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (1, 2, TO_DATE('2023-06-01', 'YYYY-MM-DD'), TO_DATE('2023-12-01', 'YYYY-MM-DD'));

-- Segunda asignación
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (2, 2, TO_DATE('2024-01-01', 'YYYY-MM-DD'), NULL);

//Caso 4: Fecha de Inicio Anterior a la Última Fecha de Fin en Otro Hotel (inválido)
-- Primera asignación
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (1, 2, TO_DATE('2023-06-01', 'YYYY-MM-DD'), TO_DATE('2023-12-01', 'YYYY-MM-DD'));

-- Segunda asignación con conflicto
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (2, 2, TO_DATE('2023-11-01', 'YYYY-MM-DD'), NULL);

//Caso 5: Fecha de Inicio en el Mismo Hotel Sin Fecha de Fin Previa (válido)
INSERT INTO Contrata (codHotel, codEmpleado, fechaInicio, fechaFin)
VALUES (1, 2, TO_DATE('2024-02-01', 'YYYY-MM-DD'), NULL);


DELETE FROM Contrata WHERE codHotel IN (1, 2);
DELETE FROM Empleado WHERE codEmpleado IN (1, 2);
DELETE FROM Hotel WHERE codHotel IN (1, 2);



// Restricción de Integridad 14
// El precio por un artículo suministrado a un hotel no puede ser menor que el del precio en suministros anteriores a ese hotel
CREATE OR REPLACE TRIGGER validar_precio_suministro
BEFORE INSERT OR UPDATE ON Suministra FOR EACH ROW
DECLARE
    precioAnterior NUMBER;
BEGIN
    SELECT MAX(precio) INTO precioAnterior
    FROM Suministra
    WHERE codArticulo = :NEW.codArticulo AND codHotel = :NEW.codHotel;

    IF precioAnterior IS NOT NULL AND :NEW.precio < precioAnterior THEN
        RAISE_APPLICATION_ERROR(-20007, 'El precio no puede ser menor que suministros anteriores.');
    END IF;
END;
/


// Restricción de Integridad 15
// Un artículo solo puede ser suministrado como mucho por dos proveedores
CREATE OR REPLACE TRIGGER validar_supledores_articulos
BEFORE INSERT OR UPDATE ON Tiene FOR EACH ROW
DECLARE
    contadorSuministrador INTEGER;
BEGIN
    SELECT COUNT(*) INTO contadorSuministrador
    FROM TieneView t
    WHERE t.codArticulo = :NEW.codArticulo;

    IF contadorSuministrador >= 2 THEN
        RAISE_APPLICATION_ERROR(-20008, 'Un artículo sólo puede ser suministrado por dos proveedores.');
    END IF;
END;
/


// Restricción de Integridad 14 - El precio por un artículo suministrado a un hotel no puede ser menor que el del precio en suministros anteriores a ese hotel
// Restricción de Integridad 17 - Ningún hotel de las provincias de Granada, Jaén, Málaga o Almería podrán solicitar artículos a proveedores de Sevilla.
// Restricción de Integridad 18 - Ningún hotel de las provincias de Córdoba, Sevilla, Cádiz o Huelva podrán solicitar artículos a proveedores de Granada.
DROP TRIGGER validar_provincias_suministros;

CREATE OR REPLACE TRIGGER validar_provincias_suministros
BEFORE INSERT OR UPDATE ON Suministra FOR EACH ROW
DECLARE
    superaPrecioAnterior NUMBER;
    provinciaHotel VARCHAR2(50);
    provinciaProveedor VARCHAR2(50);
BEGIN
    SELECT COUNT(*) INTO superaPrecioAnterior
    FROM SuministraView s
    WHERE s.codArticulo = :NEW.codArticulo AND s.codHotel = :NEW.codHotel AND s.precio >= :NEW.precio;
    
    SELECT provincia INTO provinciaHotel FROM HotelView h WHERE h.codHotel = :NEW.codHotel;
    SELECT ciudad INTO provinciaProveedor FROM ProveedorView p WHERE p.codProv = :NEW.codProv;

    IF superaPrecioAnterior > 0 THEN
        RAISE_APPLICATION_ERROR(-20008, 'El precio no puede ser menor que suministros anteriores.');
    END IF;
    
    IF (provinciaHotel IN ('Granada', 'Jaén', 'Málaga', 'Almería') AND provinciaProveedor = 'Sevilla') THEN
        RAISE_APPLICATION_ERROR(-20009, 'No se permite el suministro entre los hoteles ubicados en Granada, Jaén, Málaga y Almería a proveedores de Sevilla.');
    ELSIF (provinciaHotel IN ('Córdoba', 'Sevilla', 'Cádiz', 'Huelva') AND provinciaProveedor = 'Granada') THEN
        RAISE_APPLICATION_ERROR(-20010, 'No se permite el suministro entre los hoteles ubicados en Sevilla, Córdoba, Cádiz y Huelva a proveedores de Granada.');
    END IF;
END;
/


// Pruebas trigger 14, 17 y 18
-- Proveedores
INSERT INTO Proveedor (codProv, nombre, ciudad) VALUES (1, 'Proveedor A', 'Granada');
INSERT INTO Proveedor (codProv, nombre, ciudad) VALUES (2, 'Proveedor B', 'Sevilla');

-- Hoteles
INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (1, 'Hotel Granada', 10, 5, 'Granada', 'Granada', NULL);

INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (2, 'Hotel Sevilla', 20, 10, 'Sevilla', 'Sevilla', NULL);

-- Artículos
INSERT INTO Articulo (codArticulo, nombre, tipo) VALUES (101, 'Queso', 'A');
INSERT INTO Articulo (codArticulo, nombre, tipo) VALUES (102, 'Mantequilla', 'B');

--Tiene
INSERT INTO Tiene (codProv, codArticulo)
VALUES (1, 101);

INSERT INTO Tiene (codProv, codArticulo)
VALUES (2, 102);

-- Suministros iniciales
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (1, 1, 101, 50, 100, TO_DATE('2023-01-01', 'YYYY-MM-DD'));

INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (2, 2, 102, 30, 80, TO_DATE('2023-01-02', 'YYYY-MM-DD'));


// Caso 1: Precio Inferior al Anterior (Inválido)
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (1, 1, 101, 20, 90, TO_DATE('2023-01-05', 'YYYY-MM-DD'));

// Caso 2: Precio Igual o Superior al Anterior (Válido)
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (1, 1, 101, 20, 110, TO_DATE('2023-01-05', 'YYYY-MM-DD'));

// Caso 3: Suministro Prohibido entre Granada y Sevilla (Inválido)
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (2, 1, 101, 20, 150, TO_DATE('2023-01-06', 'YYYY-MM-DD'));

// Caso 4: Suministro Prohibido entre Sevilla y Granada (Inválido)
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (1, 2, 102, 15, 90, TO_DATE('2023-01-07', 'YYYY-MM-DD'));

// Caso 5: Suministro Permitido entre Granada y Granada (Válido)
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (1, 1, 101, 25, 120, TO_DATE('2023-01-08', 'YYYY-MM-DD'));

// Caso 6: Actualización de Precio a un Valor Inferior (Inválido)
UPDATE Suministra s
SET precio = 90
WHERE s.codProv = 1 AND s.codHotel = 1 AND s.codArticulo = 101 AND s.fecha = TO_DATE('2023-01-08', 'YYYY-MM-DD');

// Caso 7: Actualización de Precio a un Valor Superior (Válido)
UPDATE Suministra
SET precio = 150
WHERE codProv = 1 AND codHotel = 1 AND codArticulo = 101 AND fecha = TO_DATE('2023-01-01', 'YYYY-MM-DD');


// Limpieza de datos
DELETE FROM Suministra WHERE codProv IN (1, 2);
DELETE FROM Tiene WHERE codProv IN (1, 2);
DELETE FROM Proveedor WHERE codProv IN (1, 2);
DELETE FROM Hotel WHERE codHotel IN (1, 2);
DELETE FROM Articulo WHERE codArticulo IN (101, 102);



// Restricción de Integridad 19
// Borrar datos proveedor si no ha realizado ningún suministro
CREATE OR REPLACE TRIGGER prevencion_borrado_proveedor
BEFORE DELETE ON Proveedor FOR EACH ROW
DECLARE
    suministrosTotal NUMBER;
BEGIN
    SELECT SUM(cantidad) INTO suministrosTotal
    FROM Suministra
    WHERE codProv = :OLD.codProv;

    IF suministrosTotal > 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'No se puede eliminar el proveedor mientras tenga suministros activos.');
    END IF;
END;
/

// Pruebas trigger 19
-- Proveedores
INSERT INTO Proveedor (codProv, nombre, ciudad) VALUES (1, 'Proveedor A', 'Granada');
INSERT INTO Proveedor (codProv, nombre, ciudad) VALUES (2, 'Proveedor B', 'Sevilla');
INSERT INTO Proveedor (codProv, nombre, ciudad) VALUES (3, 'Proveedor C', 'Granada');

-- Artículos
INSERT INTO Articulo (codArticulo, nombre, tipo) VALUES (101, 'Queso', 'A');
INSERT INTO Articulo (codArticulo, nombre, tipo) VALUES (102, 'Mantequilla', 'B');

-- Hoteles
INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (1, 'Hotel Prueba', 10, 5, 'Granada', 'Granada', NULL);

-- Tiene
INSERT INTO Tiene (codProv, codArticulo)
VALUES (1, 101);

INSERT INTO Tiene (codProv, codArticulo)
VALUES (2, 102);

-- Suministros
INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (1, 1, 101, 50, 100, TO_DATE('2023-01-01', 'YYYY-MM-DD'));

INSERT INTO Suministra (codProv, codHotel, codArticulo, cantidad, precio, fecha)
VALUES (2, 1, 102, 0, 80, TO_DATE('2023-01-02', 'YYYY-MM-DD'));


DELETE FROM Proveedor WHERE codProv = 1;

DELETE FROM Proveedor WHERE codProv = 2;

DELETE FROM Proveedor WHERE codProv = 3;

DELETE FROM Suministra WHERE codProv IN (1, 2);
DELETE FROM Proveedor WHERE codProv IN (1, 2, 3);
DELETE FROM Articulo WHERE codArticulo IN (101, 102);
DELETE FROM Hotel WHERE codHotel IN (1, 2);
DELETE FROM Tiene WHERE codProv IN (1, 2);



// Restricción de Integridad 20
// Borrar datos artículo si no se ha pedido en ningún suministro
CREATE OR REPLACE TRIGGER prevencion_borrado_articulo
BEFORE DELETE ON Articulo FOR EACH ROW
DECLARE
    totalSuministrados NUMBER;
BEGIN
    SELECT SUM(s.cantidad) INTO totalSuministrados
    FROM SuministraView s
    WHERE s.codArticulo = :OLD.codArticulo;

    IF totalSuministrados > 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'No se puede eliminar el artículo mientras tenga suministros activos.');
    END IF;
END;
/

DELETE FROM Articulo WHERE codArticulo IN (101, 102);





-- ACTUALIZACIONES --
//DROP PROCEDURE alta_empleado;
// Actualización 1
// Introducir un nuevo empleado
CREATE OR REPLACE PROCEDURE alta_empleado(
    p_codEmpleado NUMBER,
    p_DNI VARCHAR2,
    p_nombre VARCHAR2,
    p_direccion VARCHAR2,
    p_telefono VARCHAR2,
    p_fechaContrato DATE,
    p_salario NUMBER,
    p_codHotel NUMBER,
    p_fechaInicio DATE)
IS
    contador NUMBER;
    prov Hotel.provincia%TYPE;
BEGIN
    SELECT COUNT (*) INTO contador
    FROM EmpleadoView e WHERE e.codEmpleado = p_codEmpleado;
    
    IF(contador <> 0) THEN
        RAISE_APPLICATION_ERROR(-20030, 'El empleado no puede ser insertado porque ya existe');
    
    ELSE
        SELECT provincia INTO prov
        FROM HotelView h WHERE h.codHotel = p_codHotel;
        
        IF (prov = 'Granada' OR prov = 'Jaen') THEN
                INSERT INTO  kartoffeln1.Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
                VALUES (p_codEmpleado, p_DNI, p_nombre, p_direccion, p_telefono, p_fechaContrato, p_salario);
        
                INSERT INTO  kartoffeln1.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicio);
            
        ELSIF (prov = 'Málaga' OR prov = 'Almería') THEN
                INSERT INTO  kartoffeln2.Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
                VALUES (p_codEmpleado, p_DNI, p_nombre, p_direccion, p_telefono, p_fechaContrato, p_salario);
        
                INSERT INTO  kartoffeln2.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicio);
                
        ELSIF (prov = 'Sevilla' OR prov = 'Córdoba') THEN
                INSERT INTO  kartoffeln3.Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
                VALUES (p_codEmpleado, p_DNI, p_nombre, p_direccion, p_telefono, p_fechaContrato, p_salario);
        
                INSERT INTO  kartoffeln3.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicio);
            
        ELSIF (prov = 'Cádiz' OR prov = 'Huelva') THEN
                INSERT INTO  kartoffeln4.Empleado (codEmpleado, DNI, nombre, direccion, telefono, fechaContrato, salario)
                VALUES (p_codEmpleado, p_DNI, p_nombre, p_direccion, p_telefono, p_fechaContrato, p_salario);
        
                INSERT INTO  kartoffeln4.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicio);
                
        
        ELSE
            RAISE_APPLICATION_ERROR(-20031, 'La provincia del empleado no corresponde a ningún fragmento válido.');
        END IF;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('El empleado con código ' || p_codEmpleado || ' y nombre ' || p_nombre || ' fue dado de alta correctamente.');
    END IF;
END;
/
/*
-- Crear tabla de hoteles
INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (1, 'Hotel Granada', 10, 5, 'Granada', 'Granada', NULL);

INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (2, 'Hotel Málaga', 15, 10, 'Málaga', 'Málaga', NULL);

INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (3, 'Hotel Sevilla', 20, 10, 'Sevilla', 'Sevilla', NULL);

INSERT INTO Hotel (codHotel, nombre, numHabSencillas, numHabDobles, ciudad, provincia, director)
VALUES (4, 'Hotel Cádiz', 25, 15, 'Cádiz', 'Cádiz', NULL);

// Caso 1: Insertar Empleado Nuevo (Granada) Válido
BEGIN
    alta_empleado(
        p_codEmpleado => 1,
        p_DNI => '12345678',
        p_nombre => 'Empleado Granada',
        p_direccion => 'Calle Falsa 123',
        p_telefono => '123456',
        p_fechaContrato => TO_DATE('2023-01-01', 'YYYY-MM-DD'),
        p_salario => 2000,
        p_codHotel => 1,
        p_fechaInicio => TO_DATE('2023-01-02', 'YYYY-MM-DD')
    );
END;
/

// Caso 2: Insertar Empleado Nuevo (Málaga) Valido
BEGIN
    alta_empleado(
        p_codEmpleado => 2,
        p_DNI => '87654321',
        p_nombre => 'Empleado Málaga',
        p_direccion => 'Calle Nueva 456',
        p_telefono => '654321',
        p_fechaContrato => TO_DATE('2023-02-01', 'YYYY-MM-DD'),
        p_salario => 2500,
        p_codHotel => 2,
        p_fechaInicio => TO_DATE('2023-02-02', 'YYYY-MM-DD')
    );
END;
/

// Caso 3: Insertar Empleado Nuevo (Sevilla)
BEGIN
    alta_empleado(
        p_codEmpleado => 3,
        p_DNI => '11223344',
        p_nombre => 'Empleado Sevilla',
        p_direccion => 'Calle Sevilla 789',
        p_telefono => '112233',
        p_fechaContrato => TO_DATE('2023-03-01', 'YYYY-MM-DD'),
        p_salario => 3000,
        p_codHotel => 3,
        p_fechaInicio => TO_DATE('2023-03-02', 'YYYY-MM-DD')
    );
END;
/

// Caso 4: Intentar Insertar un Empleado Existente
BEGIN
    alta_empleado(
        p_codEmpleado => 1,
        p_DNI => '12345678',
        p_nombre => 'Empleado Repetido',
        p_direccion => 'Calle Duplicada',
        p_telefono => '000000',
        p_fechaContrato => TO_DATE('2023-01-01', 'YYYY-MM-DD'),
        p_salario => 2000,
        p_codHotel => 1,
        p_fechaInicio => TO_DATE('2023-01-02', 'YYYY-MM-DD')
    );
END;
/

// Caso 5: Insertar Empleado Nuevo (Cádiz)
BEGIN
    alta_empleado(
        p_codEmpleado => 4,
        p_DNI => '55667788',
        p_nombre => 'Empleado Cádiz',
        p_direccion => 'Calle Cádiz 101',
        p_telefono => '556677',
        p_fechaContrato => TO_DATE('2023-04-01', 'YYYY-MM-DD'),
        p_salario => 4000,
        p_codHotel => 4,
        p_fechaInicio => TO_DATE('2023-04-02', 'YYYY-MM-DD')
    );
END;
/

// Limpieza de Datos
DELETE FROM kartoffeln1.Empleado WHERE codEmpleado = 1;
DELETE FROM kartoffeln2.Empleado WHERE codEmpleado = 2;
DELETE FROM kartoffeln3.Empleado WHERE codEmpleado = 3;
DELETE FROM kartoffeln4.Empleado WHERE codEmpleado = 4;

DELETE FROM kartoffeln1.Contrata WHERE codEmpleado = 1;
DELETE FROM kartoffeln2.Contrata WHERE codEmpleado = 2;
DELETE FROM kartoffeln3.Contrata WHERE codEmpleado = 3;
DELETE FROM kartoffeln4.Contrata WHERE codEmpleado = 4;
*/

// Actualización 2
// Dar de baja a un empleado
CREATE OR REPLACE PROCEDURE baja_empleado(
    p_codEmpleado NUMBER,
    p_fechaBaja DATE)
IS
    contador NUMBER;
    esDirector NUMBER;
    prov Hotel.provincia%TYPE;
       
BEGIN
    SELECT COUNT (*) INTO contador
    FROM EmpleadoView e WHERE e.codEmpleado = p_codEmpleado;
    
    IF(contador = 0) THEN
        RAISE_APPLICATION_ERROR(-20032, 'No existe ningún empleado con el código ' || p_codEmpleado || ' .');
    
    ELSE
        SELECT provincia INTO prov
        FROM HotelView h
        JOIN ContrataView c ON h.codHotel = c.codHotel
        WHERE c.codEmpleado = p_codEmpleado AND c.fechaFin IS NULL;
        
        -- Verificar si el empleado es director de algún hotel
        SELECT COUNT(*) INTO esDirector
        FROM Hotel h
        WHERE h.director = p_codEmpleado;

        -- Si es director, actualizar el atributo director a NULL
        IF esDirector > 0 THEN
            CASE
                WHEN prov IN ('Granada', 'Jaén') THEN
                    UPDATE kartoffeln1.Hotel
                    SET director = NULL
                    WHERE director = p_codEmpleado;
                WHEN prov IN ('Málaga', 'Almería') THEN
                    UPDATE kartoffeln2.Hotel
                    SET director = NULL
                    WHERE director = p_codEmpleado;
                WHEN prov IN ('Sevilla', 'Córdoba') THEN
                    UPDATE kartoffeln3.Hotel
                    SET director = NULL
                    WHERE director = p_codEmpleado;
                WHEN prov IN ('Cádiz', 'Huelva') THEN
                    UPDATE kartoffeln4.Hotel
                    SET director = NULL
                    WHERE director = p_codEmpleado;
            END CASE;
        END IF;
        
        -- Caso: Fragmento 1 (Granada, Jaén)
        IF prov IN ('Granada', 'Jaén') THEN
            UPDATE kartoffeln1.Contrata
            SET fechaFin = p_fechaBaja
            WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;
            
            DELETE FROM kartoffeln1.Empleado WHERE codEmpleado = p_codEmpleado;

        -- Caso: Fragmento 2 (Málaga, Almería)
        ELSIF prov IN ('Málaga', 'Almería') THEN
            UPDATE kartoffeln2.Contrata
            SET fechaFin = p_fechaBaja
            WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;

            DELETE FROM kartoffeln2.Empleado WHERE codEmpleado = p_codEmpleado;

        -- Caso: Fragmento 3 (Sevilla, Córdoba)
        ELSIF prov IN ('Sevilla', 'Córdoba') THEN
            UPDATE kartoffeln3.Contrata
            SET fechaFin = p_fechaBaja
            WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;

            DELETE FROM kartoffeln3.Empleado WHERE codEmpleado = p_codEmpleado;

        -- Caso: Fragmento 4 (Cádiz, Huelva)
        ELSIF prov IN ('Cádiz', 'Huelva') THEN
            UPDATE kartoffeln4.Contrata
            SET fechaFin = p_fechaBaja
            WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;

            DELETE FROM kartoffeln4.Empleado WHERE codEmpleado = p_codEmpleado;

        ELSE
            RAISE_APPLICATION_ERROR(-20033, 'La provincia del empleado no corresponde a ningún fragmento válido.');
        END IF;

        COMMIT;
        -- Mensaje de confirmación
        DBMS_OUTPUT.PUT_LINE('El empleado con código ' || p_codEmpleado || ' fue dado de baja correctamente.');
    END IF;
END;
/




// Actualización 3
// Modificar salario de un empleado
CREATE OR REPLACE PROCEDURE modificar_salario(
    p_codEmpleado NUMBER,
    p_nuevoSalario NUMBER)
IS
    contador NUMBER;
    prov Hotel.provincia%TYPE;
BEGIN
    SELECT COUNT (*) INTO contador
    FROM EmpleadoView e WHERE e.codEmpleado = p_codEmpleado;
    
    IF(contador = 0) THEN
        RAISE_APPLICATION_ERROR(-20034, 'No existe ningún empleado con el código ' || p_codEmpleado || ' .');
    
    ELSE
        SELECT h.provincia INTO prov
        FROM HotelView h
        JOIN Contrata c ON h.codHotel = c.codHotel
        WHERE c.codEmpleado = p_codEmpleado AND c.fechaFin IS NULL;
        
        CASE
            WHEN prov IN ('Granada', 'Jaén') THEN
                UPDATE kartoffeln1.Empleado
                SET salario = p_nuevoSalario
                WHERE codEmpleado = p_codEmpleado;

            WHEN prov IN ('Málaga', 'Almería') THEN
                UPDATE kartoffeln2.Empleado
                SET salario = p_nuevoSalario
                WHERE codEmpleado = p_codEmpleado;

            WHEN prov IN ('Sevilla', 'Córdoba') THEN
                UPDATE kartoffeln3.Empleado
                SET salario = p_nuevoSalario
                WHERE codEmpleado = p_codEmpleado;

            WHEN prov IN ('Cádiz', 'Huelva') THEN
                UPDATE kartoffeln4.Empleado
                SET salario = p_nuevoSalario
                WHERE codEmpleado = p_codEmpleado;

            ELSE
                RAISE_APPLICATION_ERROR(-20035, 'La provincia del empleado no corresponde a ningún fragmento válido.');
        END CASE;
    
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('El salario del empleado con código ' || p_codEmpleado || ' ha sido modificado a ' || p_nuevoSalario || ' .');
    END IF;
END;
/




// Actualización 4
// Trasladar de hotel un empleado
CREATE OR REPLACE PROCEDURE trasladar_empleado (
    p_codEmpleado NUMBER,
    p_fechaFinActual DATE,
    p_codHotel NUMBER,
    p_fechaInicioNuevo DATE,
    p_nuevaDireccion VARCHAR2 DEFAULT NULL,
    p_nuevoTelefono VARCHAR2 DEFAULT NULL)
IS
    contador NUMBER;
    prov Hotel.provincia%TYPE;
    provNuevoHotel Hotel.provincia%TYPE;
BEGIN
    SELECT COUNT (*) INTO contador
    FROM EmpleadoView e WHERE e.codEmpleado = p_codEmpleado;
    
    IF(contador = 0) THEN
        RAISE_APPLICATION_ERROR(-20036, 'No existe ningún empleado con el código ' || p_codEmpleado || ' .');
    
    ELSE
        -- Determinar la provincia del hotel actual del empleado
        SELECT h.provincia INTO prov
        FROM HotelView h
        JOIN Contrata c ON h.codHotel = c.codHotel
        WHERE c.codEmpleado = p_codEmpleado AND c.fechaFin IS NULL;
    
        -- Determinar la provincia del nuevo hotel
        SELECT h.provincia INTO provNuevoHotel
        FROM HotelView h
        WHERE h.codHotel = p_codHotel;
    
        -- Registrar la finalización en el hotel actual según el fragmento
        CASE
            WHEN prov IN ('Granada', 'Jaén') THEN
                UPDATE kartoffeln1.Contrata
                SET fechaFin = p_fechaFinActual
                WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;
    
            WHEN prov IN ('Málaga', 'Almería') THEN
                UPDATE kartoffeln2.Contrata
                SET fechaFin = p_fechaFinActual
                WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;
    
            WHEN prov IN ('Sevilla', 'Córdoba') THEN
                UPDATE kartoffeln3.Contrata
                SET fechaFin = p_fechaFinActual
                WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;
    
            WHEN prov IN ('Cádiz', 'Huelva') THEN
                UPDATE kartoffeln4.Contrata
                SET fechaFin = p_fechaFinActual
                WHERE codEmpleado = p_codEmpleado AND fechaFin IS NULL;
    
            ELSE
                RAISE_APPLICATION_ERROR(-20037, 'La provincia del hotel actual no corresponde a ningún fragmento válido.');
        END CASE;
    
        -- Crear el nuevo contrato en el hotel al que es trasladado según el fragmento
        CASE
            WHEN provNuevoHotel IN ('Granada', 'Jaén') THEN
                INSERT INTO kartoffeln1.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicioNuevo);
    
            WHEN provNuevoHotel IN ('Málaga', 'Almería') THEN
                INSERT INTO kartoffeln2.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicioNuevo);
    
            WHEN provNuevoHotel IN ('Sevilla', 'Córdoba') THEN
                INSERT INTO kartoffeln3.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicioNuevo);
    
            WHEN provNuevoHotel IN ('Cádiz', 'Huelva') THEN
                INSERT INTO kartoffeln4.Contrata (codHotel, codEmpleado, fechaInicio)
                VALUES (p_codHotel, p_codEmpleado, p_fechaInicioNuevo);
    
            ELSE
                RAISE_APPLICATION_ERROR(-20038, 'La provincia del nuevo hotel no corresponde a ningún fragmento válido.');
        END CASE;
    
        -- Actualizar los datos de dirección y teléfono del empleado según el fragmento
        IF p_nuevaDireccion IS NOT NULL OR p_nuevoTelefono IS NOT NULL THEN
            CASE
                WHEN prov IN ('Granada', 'Jaén') THEN
                    UPDATE kartoffeln1.Empleado
                    SET direccion = NVL(p_nuevaDireccion, direccion),
                        telefono = NVL(p_nuevoTelefono, telefono)
                    WHERE codEmpleado = p_codEmpleado;
    
                WHEN prov IN ('Málaga', 'Almería') THEN
                    UPDATE kartoffeln2.Empleado
                    SET direccion = NVL(p_nuevaDireccion, direccion),
                        telefono = NVL(p_nuevoTelefono, telefono)
                    WHERE codEmpleado = p_codEmpleado;
    
                WHEN prov IN ('Sevilla', 'Córdoba') THEN
                    UPDATE kartoffeln3.Empleado
                    SET direccion = NVL(p_nuevaDireccion, direccion),
                        telefono = NVL(p_nuevoTelefono, telefono)
                    WHERE codEmpleado = p_codEmpleado;
    
                WHEN prov IN ('Cádiz', 'Huelva') THEN
                    UPDATE kartoffeln4.Empleado
                    SET direccion = NVL(p_nuevaDireccion, direccion),
                        telefono = NVL(p_nuevoTelefono, telefono)
                    WHERE codEmpleado = p_codEmpleado;
    
                ELSE
                    RAISE_APPLICATION_ERROR(-20039, 'No se pudo determinar el fragmento del empleado para actualizar sus datos personales.');
            END CASE;
        END IF;
    
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('El empleado con código ' || p_codEmpleado || ' ha sido trasladado al hotel ' || p_codHotel || '.');
    END IF;
END;
/



// Actualización 5
// Dar de alta un nuevo hotel
CREATE OR REPLACE PROCEDURE alta_hotel (
    p_codHotel NUMBER,
    p_nombre VARCHAR2,
    p_ciudad VARCHAR2,
    p_provincia VARCHAR2,
    p_numHabSencillas INTEGER,
    p_numHabDobles INTEGER)
IS
BEGIN
    -- Insertar el nuevo hotel en el fragmento correspondiente según la provincia
    CASE
        WHEN p_provincia IN ('Granada', 'Jaén') THEN
            INSERT INTO kartoffeln1.Hotel (codHotel, nombre, ciudad, provincia, numHabSencillas, numHabDobles)
            VALUES (p_codHotel, p_nombre, p_ciudad, p_provincia, p_numHabSencillas, p_numHabDobles);

        WHEN p_provincia IN ('Málaga', 'Almería') THEN
            INSERT INTO kartoffeln2.Hotel (codHotel, nombre, ciudad, provincia, numHabSencillas, numHabDobles)
            VALUES (p_codHotel, p_nombre, p_ciudad, p_provincia, p_numHabSencillas, p_numHabDobles);

        WHEN p_provincia IN ('Sevilla', 'Córdoba') THEN
            INSERT INTO kartoffeln3.Hotel (codHotel, nombre, ciudad, provincia, numHabSencillas, numHabDobles)
            VALUES (p_codHotel, p_nombre, p_ciudad, p_provincia, p_numHabSencillas, p_numHabDobles);

        WHEN p_provincia IN ('Cádiz', 'Huelva') THEN
            INSERT INTO kartoffeln4.Hotel (codHotel, nombre, ciudad, provincia, numHabSencillas, numHabDobles)
            VALUES (p_codHotel, p_nombre, p_ciudad, p_provincia, p_numHabSencillas, p_numHabDobles);

        ELSE
            RAISE_APPLICATION_ERROR(-20040, 'La provincia especificada no corresponde a ningún fragmento válido.');
    END CASE;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El hotel "' || p_nombre || '" ha sido dado de alta correctamente en la provincia ' || p_provincia || '.');
END;
/


// Actualización 6
// Cambiar director de un hotel
CREATE OR REPLACE PROCEDURE cambiar_director (
    p_codHotel NUMBER,
    p_ID_Director NUMBER)
IS
    prov Hotel.provincia%TYPE;
    esEmpleadoActivo NUMBER;
BEGIN
    -- Determinar la provincia del hotel
    SELECT h.provincia INTO prov
    FROM HotelView h
    WHERE h.codHotel = p_codHotel;

    -- Verificar si el nuevo director es un empleado activo en algún fragmento
    SELECT COUNT(*) INTO esEmpleadoActivo
    FROM EmpleadoView e
    WHERE e.codEmpleado = p_ID_Director;

    IF esEmpleadoActivo = 0 THEN
        RAISE_APPLICATION_ERROR(-20041, 'El nuevo director no es un empleado válido.');
    END IF;

    -- Actualizar el director del hotel en el fragmento correspondiente
    CASE
        WHEN prov IN ('Granada', 'Jaén') THEN
            UPDATE kartoffeln1.Hotel
            SET director = p_ID_Director
            WHERE codHotel = p_codHotel;

        WHEN prov IN ('Málaga', 'Almería') THEN
            UPDATE kartoffeln2.Hotel
            SET director = p_ID_Director
            WHERE codHotel = p_codHotel;

        WHEN prov IN ('Sevilla', 'Córdoba') THEN
            UPDATE kartoffeln3.Hotel
            SET director = p_ID_Director
            WHERE codHotel = p_codHotel;

        WHEN prov IN ('Cádiz', 'Huelva') THEN
            UPDATE kartoffeln4.Hotel
            SET director = p_ID_Director
            WHERE codHotel = p_codHotel;

        ELSE
            RAISE_APPLICATION_ERROR(-20042, 'La provincia especificada no corresponde a ningún fragmento válido.');
    END CASE;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El director del hotel con código ' || p_codHotel || ' ha sido cambiado correctamente al empleado ' || p_ID_Director || '.');
END;
/



// Actualización 7
// Dar de alta a un nuevo cliente
CREATE OR REPLACE PROCEDURE alta_cliente (
    p_codCliente NUMBER,
    p_DNI VARCHAR2,
    p_nombre VARCHAR2,
    p_telefono VARCHAR2)
IS
BEGIN
    -- Insertar el cliente en cada fragmento
    BEGIN
        INSERT INTO kartoffeln1.Cliente (codCliente, DNI, nombre, telefono)
        VALUES (p_codCliente, p_DNI, p_nombre, p_telefono);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20043, 'El cliente ya existe en el fragmento kartoffeln1.');
    END;

    BEGIN
        INSERT INTO kartoffeln2.Cliente (codCliente, DNI, nombre, telefono)
        VALUES (p_codCliente, p_DNI, p_nombre, p_telefono);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20044, 'El cliente ya existe en el fragmento kartoffeln2.');
    END;

    BEGIN
        INSERT INTO kartoffeln3.Cliente (codCliente, DNI, nombre, telefono)
        VALUES (p_codCliente, p_DNI, p_nombre, p_telefono);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20045, 'El cliente ya existe en el fragmento kartoffeln3.');
    END;

    BEGIN
        INSERT INTO kartoffeln4.Cliente (codCliente, DNI, nombre, telefono)
        VALUES (p_codCliente, p_DNI, p_nombre, p_telefono);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20046, 'El cliente ya existe en el fragmento kartoffeln4.');
    END;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El cliente "' || p_nombre || '" ha sido dado de alta correctamente en todas las localidades.');
END;
/



// Actualización 8
// Dar de alta o actualizar una reserva
CREATE OR REPLACE PROCEDURE gestionar_reserva (
    p_codCliente NUMBER,
    p_codHotel NUMBER,
    p_tipoHab VARCHAR2,
    p_fechaEntrada DATE,
    p_fechaSalida DATE,
    p_precio NUMBER
) IS
    prov Hotel.provincia%TYPE;
    clienteExiste NUMBER;
    reservaExiste NUMBER;
BEGIN
    -- Verificar si el cliente existe en al menos un fragmento
    SELECT COUNT(*) INTO clienteExiste
    FROM (
        SELECT codCliente FROM kartoffeln1.Cliente
        UNION ALL
        SELECT codCliente FROM kartoffeln2.Cliente
        UNION ALL
        SELECT codCliente FROM kartoffeln3.Cliente
        UNION ALL
        SELECT codCliente FROM kartoffeln4.Cliente
    ) WHERE codCliente = p_codCliente;

    IF clienteExiste = 0 THEN
        RAISE_APPLICATION_ERROR(-20047, 'Error: El cliente no existe.');
    
    ELSE
        -- Determinar la provincia del hotel
        SELECT h.provincia INTO prov
        FROM HotelView h
        WHERE h.codHotel = p_codHotel;
    
        -- Proceder según el fragmento del hotel
        CASE
            WHEN prov IN ('Granada', 'Jaén') THEN
                -- Verificar si ya existe una reserva
                SELECT COUNT(*)
                INTO reservaExiste
                FROM kartoffeln1.Reserva
                WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                  AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;

                IF reservaExiste > 0 THEN
                    -- Actualizar la reserva existente
                    UPDATE kartoffeln1.Reserva
                    SET tipoHab = p_tipoHab, precio = p_precio
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
                ELSE
                    -- Crear una nueva reserva
                    INSERT INTO kartoffeln1.Reserva (codCliente, codHotel, tipoHab, fechaEntrada, fechaSalida, precio)
                    VALUES (p_codCliente, p_codHotel, p_tipoHab, p_fechaEntrada, p_fechaSalida, p_precio);
                END IF;

            WHEN prov IN ('Málaga', 'Almería') THEN
                SELECT COUNT(*)
                INTO reservaExiste
                FROM kartoffeln2.Reserva
                WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                  AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;

                IF reservaExiste > 0 THEN
                    UPDATE kartoffeln2.Reserva
                    SET tipoHab = p_tipoHab, precio = p_precio
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
                ELSE
                    INSERT INTO kartoffeln2.Reserva (codCliente, codHotel, tipoHab, fechaEntrada, fechaSalida, precio)
                    VALUES (p_codCliente, p_codHotel, p_tipoHab, p_fechaEntrada, p_fechaSalida, p_precio);
                END IF;

            WHEN prov IN ('Sevilla', 'Córdoba') THEN
                SELECT COUNT(*)
                INTO reservaExiste
                FROM kartoffeln3.Reserva
                WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                  AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;

                IF reservaExiste > 0 THEN
                    UPDATE kartoffeln3.Reserva
                    SET tipoHab = p_tipoHab, precio = p_precio
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
                ELSE
                    INSERT INTO kartoffeln3.Reserva (codCliente, codHotel, tipoHab, fechaEntrada, fechaSalida, precio)
                    VALUES (p_codCliente, p_codHotel, p_tipoHab, p_fechaEntrada, p_fechaSalida, p_precio);
                END IF;

            WHEN prov IN ('Cádiz', 'Huelva') THEN
                SELECT COUNT(*)
                INTO reservaExiste
                FROM kartoffeln4.Reserva
                WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                  AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;

                IF reservaExiste > 0 THEN
                    UPDATE kartoffeln4.Reserva
                    SET tipoHab = p_tipoHab, precio = p_precio
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
                ELSE
                    INSERT INTO kartoffeln4.Reserva (codCliente, codHotel, tipoHab, fechaEntrada, fechaSalida, precio)
                    VALUES (p_codCliente, p_codHotel, p_tipoHab, p_fechaEntrada, p_fechaSalida, p_precio);
                END IF;

            ELSE
                RAISE_APPLICATION_ERROR(-20048, 'Error: La provincia del hotel no corresponde a ningún fragmento válido.');
        END CASE;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('La reserva para el cliente ' || p_codCliente || ' en el hotel ' || p_codHotel || ' ha sido gestionada correctamente.');
    END IF;
END;
/





// Actualización 9
// Anular una reserva
CREATE OR REPLACE PROCEDURE anular_reserva (
    p_codCliente NUMBER,
    p_codHotel NUMBER,
    p_fechaEntrada DATE,
    p_fechaSalida DATE
) IS
    prov Hotel.provincia%TYPE;
    clienteExiste NUMBER;
    hotelExiste NUMBER;
BEGIN
    -- Verificar si el cliente existe en al menos un fragmento
    SELECT COUNT(*) INTO clienteExiste
    FROM (
        SELECT codCliente FROM kartoffeln1.Cliente
        UNION ALL
        SELECT codCliente FROM kartoffeln2.Cliente
        UNION ALL
        SELECT codCliente FROM kartoffeln3.Cliente
        UNION ALL
        SELECT codCliente FROM kartoffeln4.Cliente
    ) WHERE codCliente = p_codCliente;

    IF clienteExiste = 0 THEN
        RAISE_APPLICATION_ERROR(-20049, 'Error: El cliente no existe.');
    
    ELSE
        -- Verificar si el hotel existe
        SELECT COUNT(*) INTO hotelExiste
        FROM HotelView h WHERE h.codHotel = p_codHotel;
        
        IF hotelExiste = 0 THEN
            RAISE_APPLICATION_ERROR(-20050, 'No se ha encontrado ningún hotel con el código ' || p_codHotel ||' .');
        
        ELSE
            -- Determinar la provincia del hotel
            SELECT h.provincia INTO prov
            FROM HotelView h
            WHERE h.codHotel = p_codHotel;
        
            -- Proceder según el fragmento del hotel
            CASE
                WHEN prov IN ('Granada', 'Jaén') THEN
                    DELETE FROM kartoffeln1.Reserva
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
        
                WHEN prov IN ('Málaga', 'Almería') THEN
                    DELETE FROM kartoffeln2.Reserva
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
        
                WHEN prov IN ('Sevilla', 'Córdoba') THEN
                    DELETE FROM kartoffeln3.Reserva
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
        
                WHEN prov IN ('Cádiz', 'Huelva') THEN
                    DELETE FROM kartoffeln4.Reserva
                    WHERE codCliente = p_codCliente AND codHotel = p_codHotel
                      AND fechaEntrada = p_fechaEntrada AND fechaSalida = p_fechaSalida;
        
                ELSE
                    RAISE_APPLICATION_ERROR(-20051, 'Error: La provincia del hotel no corresponde a ningún fragmento válido.');
            END CASE;
        END IF;
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('La reserva para el cliente ' || p_codCliente || ' en el hotel ' || p_codHotel || ' ha sido anulada correctamente.');
END;
/




// Actualización 10
// Dar de alta a un nuevo proveedor
CREATE OR REPLACE PROCEDURE alta_proveedor (
    p_codProv NUMBER,
    p_nombre VARCHAR2,
    p_ciudad VARCHAR2)
IS
BEGIN
    -- Verificar que la ciudad sea válida (Granada o Sevilla)
    IF p_ciudad NOT IN ('Granada', 'Sevilla') THEN
        RAISE_APPLICATION_ERROR(-20052, 'La ciudad debe ser Granada o Sevilla.');
    
    ELSE
        -- Insertar el proveedor en el fragmento correspondiente según la ciudad
        CASE
            WHEN p_ciudad = 'Granada' THEN
                BEGIN
                    INSERT INTO kartoffeln1.Proveedor (codProv, nombre, ciudad)
                    VALUES (p_codProv, p_nombre, p_ciudad);
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        RAISE_APPLICATION_ERROR(-20053, 'El proveedor ya existe en Granada.');
                END;
    
            WHEN p_ciudad = 'Sevilla' THEN
                BEGIN
                    INSERT INTO kartoffeln3.Proveedor (codProv, nombre, ciudad)
                    VALUES (p_codProv, p_nombre, p_ciudad);
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        RAISE_APPLICATION_ERROR(-20054, 'El proveedor ya existe en Sevilla.');
                END;
    
            ELSE
                RAISE_APPLICATION_ERROR(-20055, 'Error inesperado: la ciudad no corresponde a ningún fragmento válido.');
        END CASE;
    
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('El proveedor "' || p_nombre || '" ha sido dado de alta correctamente en ' || p_ciudad || '.');
    END IF;
END;
/



// Actualización 11
// Dar de baja a un proveedor
CREATE OR REPLACE PROCEDURE baja_proveedor (
    p_codProv NUMBER
) IS
    suministrosActivos NUMBER := 0;
    tieneRelacion NUMBER := 0;
    ciudadProveedor Proveedor.ciudad%TYPE;
BEGIN
    -- Determinar la ciudad del proveedor
    SELECT ciudad INTO ciudadProveedor
    FROM ProveedorView p
    WHERE p.codProv = p_codProv;

    -- Verificar si el proveedor tiene suministros activos
    CASE
        WHEN ciudadProveedor = 'Granada' THEN
            SELECT COUNT(*) INTO suministrosActivos
            FROM kartoffeln1.Suministra
            WHERE codProv = p_codProv AND cantidad > 0;

        WHEN ciudadProveedor = 'Sevilla' THEN
            SELECT COUNT(*) INTO suministrosActivos
            FROM kartoffeln3.Suministra
            WHERE codProv = p_codProv AND cantidad > 0;

        ELSE
            RAISE_APPLICATION_ERROR(-20056, 'La ciudad del proveedor debe ser Granada o Sevilla.');
    END CASE;

    IF suministrosActivos > 0 THEN
        RAISE_APPLICATION_ERROR(-20057, 'No se puede eliminar el proveedor porque tiene suministros activos.');
    END IF;

    -- Verificar si el proveedor tiene relaciones activas en la tabla Tiene
    CASE
        WHEN ciudadProveedor = 'Granada' THEN
            SELECT COUNT(*) INTO tieneRelacion
            FROM kartoffeln1.Tiene
            WHERE codProv = p_codProv;

        WHEN ciudadProveedor = 'Sevilla' THEN
            SELECT COUNT(*) INTO tieneRelacion
            FROM kartoffeln3.Tiene
            WHERE codProv = p_codProv;

        ELSE
            RAISE_APPLICATION_ERROR(-20056, 'La ciudad del proveedor debe ser Granada o Sevilla.');
    END CASE;

    IF tieneRelacion > 0 THEN
        RAISE_APPLICATION_ERROR(-20058, 'No se puede eliminar el proveedor porque tiene relaciones activas en la tabla Tiene.');
    END IF;

    -- Eliminar el proveedor del fragmento correspondiente
    CASE
        WHEN ciudadProveedor = 'Granada' THEN
            DELETE FROM kartoffeln1.Proveedor WHERE codProv = p_codProv;

        WHEN ciudadProveedor = 'Sevilla' THEN
            DELETE FROM kartoffeln3.Proveedor WHERE codProv = p_codProv;

        ELSE
            RAISE_APPLICATION_ERROR(-20056, 'La ciudad del proveedor debe ser Granada o Sevilla.');
    END CASE;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El proveedor con código ' || p_codProv || ' ha sido eliminado correctamente.');
END;
/




// Actualización 12
// Dar de alta o actualizar un suministro
CREATE OR REPLACE PROCEDURE gestionar_suministro (
    p_codArticulo NUMBER,
    p_codProv NUMBER,
    p_codHotel NUMBER,
    p_fecha DATE,
    p_cantidad NUMBER,
    p_precio NUMBER
) IS
    ciudadProveedor Proveedor.ciudad%TYPE;
    suministroExiste NUMBER := 0;
    cantidadActual NUMBER := 0;
BEGIN
    -- Determinar la ciudad del proveedor
    SELECT ciudad INTO ciudadProveedor
    FROM ProveedorView p
    WHERE p.codProv = p_codProv;

    -- Proceder según la ciudad del proveedor
    IF ciudadProveedor = 'Granada' THEN
        -- Verificar si ya existe un suministro en kartoffeln1.Suministra
        SELECT COUNT(*) INTO suministroExiste
        FROM kartoffeln1.Suministra
        WHERE codArticulo = p_codArticulo AND codProv = p_codProv AND codHotel = p_codHotel AND fecha = p_fecha;

        IF suministroExiste > 0 THEN
            -- Actualizar el suministro existente
            UPDATE kartoffeln1.Suministra
            SET cantidad = cantidad + p_cantidad, precio = p_precio
            WHERE codArticulo = p_codArticulo AND codProv = p_codProv AND codHotel = p_codHotel AND fecha = p_fecha;

            -- Verificar que la cantidad total no sea negativa
            SELECT cantidad INTO cantidadActual
            FROM kartoffeln1.Suministra
            WHERE codArticulo = p_codArticulo AND codProv = p_codProv AND codHotel = p_codHotel AND fecha = p_fecha;

            IF cantidadActual < 0 THEN
                RAISE_APPLICATION_ERROR(-20057, 'La cantidad total no puede ser negativa.');
            END IF;
        ELSE
            -- Insertar un nuevo suministro
            INSERT INTO kartoffeln1.Suministra (codArticulo, codProv, codHotel, fecha, cantidad, precio)
            VALUES (p_codArticulo, p_codProv, p_codHotel, p_fecha, p_cantidad, p_precio);
        END IF;

    ELSIF ciudadProveedor = 'Sevilla' THEN
        -- Verificar si ya existe un suministro en kartoffeln3.Suministra
        SELECT COUNT(*) INTO suministroExiste
        FROM kartoffeln3.Suministra
        WHERE codArticulo = p_codArticulo AND codProv = p_codProv AND codHotel = p_codHotel AND fecha = p_fecha;

        IF suministroExiste > 0 THEN
            -- Actualizar el suministro existente
            UPDATE kartoffeln3.Suministra
            SET cantidad = cantidad + p_cantidad, precio = p_precio
            WHERE codArticulo = p_codArticulo AND codProv = p_codProv AND codHotel = p_codHotel AND fecha = p_fecha;

            -- Verificar que la cantidad total no sea negativa
            SELECT cantidad INTO cantidadActual
            FROM kartoffeln3.Suministra
            WHERE codArticulo = p_codArticulo AND codProv = p_codProv AND codHotel = p_codHotel AND fecha = p_fecha;

            IF cantidadActual < 0 THEN
                RAISE_APPLICATION_ERROR(-20057, 'La cantidad total no puede ser negativa.');
            END IF;
        ELSE
            -- Insertar un nuevo suministro
            INSERT INTO kartoffeln3.Suministra (codArticulo, codProv, codHotel, fecha, cantidad, precio)
            VALUES (p_codArticulo, p_codProv, p_codHotel, p_fecha, p_cantidad, p_precio);
        END IF;

    ELSE
        RAISE_APPLICATION_ERROR(-20058, 'La ciudad del proveedor debe ser Granada o Sevilla.');
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El suministro del artículo ' || p_codArticulo || ' con proveedor ' || p_codProv || ' ha sido gestionado correctamente.');
END;
/





// Actualización 13
// Dar de baja suministros
CREATE OR REPLACE PROCEDURE baja_suministros (
    p_codHotel NUMBER,
    p_codArticulo NUMBER,
    p_fecha DATE DEFAULT NULL
) IS
    ciudadProveedor Proveedor.ciudad%TYPE;
BEGIN
    -- Determinar la ciudad del proveedor asociada al artículo
    SELECT ciudad INTO ciudadProveedor
    FROM (
        SELECT s.codProv, s.codHotel, s.codArticulo, p.ciudad
        FROM kartoffeln1.Suministra s
        JOIN kartoffeln1.Proveedor p ON s.codProv = p.codProv
        UNION ALL
        SELECT s.codProv, s.codHotel, s.codArticulo, p.ciudad
        FROM kartoffeln3.Suministra s
        JOIN kartoffeln3.Proveedor p ON s.codProv = p.codProv
    ) suministros
    WHERE codHotel = p_codHotel AND codArticulo = p_codArticulo;

    -- Proceder según la ciudad del proveedor
    IF ciudadProveedor = 'Granada' THEN
        IF p_fecha IS NOT NULL THEN
            -- Eliminar suministros específicos por fecha en kartoffeln1
            DELETE FROM kartoffeln1.Suministra
            WHERE codHotel = p_codHotel AND codArticulo = p_codArticulo AND fecha = p_fecha;
        ELSE
            -- Eliminar todos los suministros del artículo en el hotel en kartoffeln1
            DELETE FROM kartoffeln1.Suministra
            WHERE codHotel = p_codHotel AND codArticulo = p_codArticulo;
        END IF;

    ELSIF ciudadProveedor = 'Sevilla' THEN
        IF p_fecha IS NOT NULL THEN
            -- Eliminar suministros específicos por fecha en kartoffeln3
            DELETE FROM kartoffeln3.Suministra
            WHERE codHotel = p_codHotel AND codArticulo = p_codArticulo AND fecha = p_fecha;
        ELSE
            -- Eliminar todos los suministros del artículo en el hotel en kartoffeln3
            DELETE FROM kartoffeln3.Suministra
            WHERE codHotel = p_codHotel AND codArticulo = p_codArticulo;
        END IF;

    ELSE
        RAISE_APPLICATION_ERROR(-20059, 'La ciudad del proveedor debe ser Granada o Sevilla.');
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Los suministros del artículo ' || p_codArticulo || ' en el hotel ' || p_codHotel || ' han sido eliminados correctamente.');
END;
/




// Actualización 14
// Dar de alta un nuevo artículo
CREATE OR REPLACE PROCEDURE alta_articulo (
    p_codArticulo NUMBER,
    p_nombre VARCHAR2,
    p_tipo CHAR,
    p_codProv NUMBER)
IS
    ciudadProveedor Proveedor.ciudad%TYPE;
BEGIN
    -- Validar el tipo de artículo
    IF p_tipo NOT IN ('A', 'B', 'C', 'D') THEN
        RAISE_APPLICATION_ERROR(-20060, 'El tipo de artículo debe ser A, B, C o D.');
    END IF;

    -- Determinar la ciudad del proveedor
    SELECT ciudad INTO ciudadProveedor
    FROM ProveedorView p
    WHERE p.codProv = p_codProv;

    -- Insertar el artículo en todas las réplicas
    BEGIN
        INSERT INTO kartoffeln1.Articulo (codArticulo, nombre, tipo)
        VALUES (p_codArticulo, p_nombre, p_tipo);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL; -- Si ya existe en esta réplica, continuar
    END;

    BEGIN
        INSERT INTO kartoffeln2.Articulo (codArticulo, nombre, tipo)
        VALUES (p_codArticulo, p_nombre, p_tipo);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL; -- Si ya existe en esta réplica, continuar
    END;

    BEGIN
        INSERT INTO kartoffeln3.Articulo (codArticulo, nombre, tipo)
        VALUES (p_codArticulo, p_nombre, p_tipo);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL; -- Si ya existe en esta réplica, continuar
    END;

    BEGIN
        INSERT INTO kartoffeln4.Articulo (codArticulo, nombre, tipo)
        VALUES (p_codArticulo, p_nombre, p_tipo);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL; -- Si ya existe en esta réplica, continuar
    END;

    -- Asociar el artículo con el proveedor en el fragmento correspondiente
    CASE
        WHEN ciudadProveedor = 'Granada' THEN
            INSERT INTO kartoffeln1.Tiene (codProv, codArticulo)
            VALUES (p_codProv, p_codArticulo);

        WHEN ciudadProveedor = 'Sevilla' THEN
            INSERT INTO kartoffeln3.Tiene (codProv, codArticulo)
            VALUES (p_codProv, p_codArticulo);

        ELSE
            RAISE_APPLICATION_ERROR(-20061, 'La ciudad del proveedor debe ser Granada o Sevilla.');
    END CASE;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El artículo "' || p_nombre || '" ha sido dado de alta correctamente y asociado al proveedor ' || p_codProv || '.');
END;
/





// Actualización 15
// Dar de baja un artículo
CREATE OR REPLACE PROCEDURE baja_articulo (
    p_codArticulo NUMBER
) IS
    suministrosActivos NUMBER := 0;
BEGIN
    -- Verificar si el artículo tiene suministros activos en cualquier fragmento
    SELECT COUNT(*) INTO suministrosActivos
    FROM SuministraView s
    WHERE s.codArticulo = p_codArticulo AND s.cantidad > 0;

    IF suministrosActivos > 0 THEN
        RAISE_APPLICATION_ERROR(-20062, 'No se puede eliminar el artículo porque tiene suministros activos.');
    END IF;

    -- Eliminar los suministros relacionados con el artículo en todos los fragmentos
    DELETE FROM kartoffeln1.Suministra WHERE codArticulo = p_codArticulo;
    DELETE FROM kartoffeln3.Suministra WHERE codArticulo = p_codArticulo;

    -- Eliminar la relación con los proveedores en los fragmentos correspondientes
    DELETE FROM kartoffeln1.Tiene WHERE codArticulo = p_codArticulo;
    DELETE FROM kartoffeln3.Tiene WHERE codArticulo = p_codArticulo;

    -- Eliminar el artículo de todas las réplicas
    BEGIN
        DELETE FROM kartoffeln1.Articulo WHERE codArticulo = p_codArticulo;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL; -- Si no existe, continuar
    END;

    BEGIN
        DELETE FROM kartoffeln2.Articulo WHERE codArticulo = p_codArticulo;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL; -- Si no existe, continuar
    END;

    BEGIN
        DELETE FROM kartoffeln3.Articulo WHERE codArticulo = p_codArticulo;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL; -- Si no existe, continuar
    END;

    BEGIN
        DELETE FROM kartoffeln4.Articulo WHERE codArticulo = p_codArticulo;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL; -- Si no existe, continuar
    END;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('El artículo con código ' || p_codArticulo || ' ha sido eliminado correctamente.');
END;
/


