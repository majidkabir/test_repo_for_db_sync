SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_705ExtVal01                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 13-Feb-2019 1.0  James       WMS7795. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_705ExtVal01] (  
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @tVar             VariableTable READONLY,
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cRef01      NVARCHAR( 60)
   DECLARE @cRef02      NVARCHAR( 60)
   DECLARE @cRef03      NVARCHAR( 60)
   DECLARE @cRef04      NVARCHAR( 60)
   DECLARE @cRef05      NVARCHAR( 60)
   DECLARE @cUDF01      NVARCHAR( 60)
   DECLARE @cUDF02      NVARCHAR( 60)
   DECLARE @cUDF03      NVARCHAR( 60)
   DECLARE @cUDF04      NVARCHAR( 60)
   DECLARE @cUDF05      NVARCHAR( 60)
   DECLARE @cRefValue   NVARCHAR( 60)
   DECLARE @cJobType    NVARCHAR( 20)
   DECLARE @cColumnName NVARCHAR( 20)
   DECLARE @cDataType   NVARCHAR( 128)
   DECLARE @n_Err       INT
   DECLARE @n           INT

   -- Variable mapping
   SELECT @cRef01 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cRef01'
   SELECT @cJobType = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cJobType'
   

   IF @nFunc = 705 -- Data capture 9
   BEGIN
      IF @nStep = 2 -- Job type
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF EXISTS (SELECT 1
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'JOBCapType'
               AND   Code = @cJobType
               AND   StorerKey = @cStorerKey
               AND   Code2 = @cFacility
               AND   UDF03 = '1')
            BEGIN
               SELECT @cUDF01 = UDF01, 
                      @cUDF02 = UDF02, 
                      @cUDF03 = UDF03, 
                      @cUDF04 = UDF04, 
                      @cUDF05 = UDF05
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'JOBCapCol'
               AND   Code = @cJobType
               AND   StorerKey = @cStorerKey
               AND   Code2 = @cFacility

               SET @n = 1

               WHILE @n < 5
               BEGIN
                  IF @n = 1 SET @cColumnName = @cUDF01
                  IF @n = 2 SET @cColumnName = @cUDF02
                  IF @n = 3 SET @cColumnName = @cUDF03
                  IF @n = 4 SET @cColumnName = @cUDF04
                  IF @n = 5 SET @cColumnName = @cUDF05

                  IF @cColumnName <> ''
                  BEGIN
                     IF NOT EXISTS (
                        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                        WHERE TABLE_NAME = 'rdtSTDEventLog' 
                        AND   COLUMN_NAME = @cColumnName)
                     BEGIN
                        SET @nErrNo = 134301
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Col
                        GOTO Quit
                     END
                  END

                  SET @n = @n + 1
                  SET @cColumnName = ''
               END
            END
         END   -- InputKey
      END   -- Step

      IF @nStep = 4 -- Ref
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cUDF01 = UDF01, 
                   @cUDF02 = UDF02, 
                   @cUDF03 = UDF03, 
                   @cUDF04 = UDF04, 
                   @cUDF05 = UDF05
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'JOBCapCol'
            AND   Code = @cJobType
            AND   StorerKey = @cStorerKey
            AND   Code2 = @cFacility

            SET @n = 1

            WHILE @n < 6
            BEGIN
               IF @n = 1 SET @cColumnName = @cUDF01
               IF @n = 2 SET @cColumnName = @cUDF02
               IF @n = 3 SET @cColumnName = @cUDF03
               IF @n = 4 SET @cColumnName = @cUDF04
               IF @n = 5 SET @cColumnName = @cUDF05

               IF @cColumnName <> ''
               BEGIN
                  -- Get lookup field data type
                  SET @cDataType = ''
                  SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'rdtSTDEventLog' 
                  AND   COLUMN_NAME = @cColumnName

                  IF @cDataType <> ''
                  BEGIN
                     IF @cDataType = 'nvarchar' AND ISNULL( @cRefValue, '') = '' SET @n_Err = 0 ELSE
                     IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRef01)     ELSE
                     IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRef01)     ELSE
                     IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRef01, 20)

                     -- Check data type
                     IF @n_Err = 0
                     BEGIN
                        SET @nErrNo = 134302
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
                        GOTO Quit
                     END
                  END
               END

               SET @n = @n + 1
               SET @cColumnName = ''
            END
         END   -- InputKey
      END   -- Step
   END   -- Func

   Quit:
END  

GO