SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt.rdt_855ExtInfo05                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2018-10-30 1.0  Ung      WMS-6842 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_855ExtInfo05]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nCount            INT
   DECLARE @nRowCount         INT

   DECLARE @cErrMsg01         NVARCHAR( 20)
   DECLARE @cErrMsg02         NVARCHAR( 20)
   DECLARE @cErrMsg03         NVARCHAR( 20)
   DECLARE @cErrMsg04         NVARCHAR( 20)
   DECLARE @cErrMsg05         NVARCHAR( 20)
   
   DECLARE @cVAS_Activity     NVARCHAR( 20)
   DECLARE @cVAS_SKU          NVARCHAR( 20)
   DECLARE @cVAS_OrderKey     NVARCHAR( 10)
   DECLARE @cVAS_OrderLineNo  NVARCHAR( 5)
   DECLARE @cNotes            NVARCHAR( 20)

   DECLARE @curVAS CURSOR

   IF @nFunc = 855 -- PPA by DropID
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check SKU key-in
            IF EXISTS( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile AND I_Field01 = '' )
               GOTO Quit
            
            -- Variable mapping
            DECLARE @cDropID NVARCHAR( 20)
            DECLARE @cSKU NVARCHAR( 20)
            SELECT @cDropID = Value FROM @tExtInfo WHERE Variable = '@cDropID'
            SELECT @cSKU = Value FROM @tExtInfo WHERE Variable = '@cSKU'

            SET @cVAS_OrderKey = ''
            SELECT TOP 1 
               @cVAS_OrderKey = PD.OrderKey, 
               @cVAS_OrderLineNo = PD.OrderLineNumber
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.CaseID = @cDropID

            -- Get VAS instruction
            SET @cNotes = ''
            SELECT @cNotes = SUBSTRING( Note1, 1, 20)
               FROM dbo.OrderDetailRef WITH (NOLOCK)
               WHERE OrderKey = @cVAS_OrderKey
                  AND OrderLineNumber = @cVAS_OrderLineNo
                  AND StorerKey = @cStorerKey
                  AND ParentSKU = @cSKU
            SET @nRowCount = @@ROWCOUNT
            
            IF @nRowCount = 0
               GOTO Quit
               
            ELSE IF @nRowCount = 1
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cNotes
               SET @nErrNo = 0
               GOTO Quit
            END
               
            ELSE
            BEGIN
               SET @cErrMsg01 = ''
               SET @cErrMsg02 = ''
               SET @cErrMsg03 = ''
               SET @cErrMsg04 = ''
               SET @cErrMsg05 = ''
               SET @nCount = 1

               -- Loop VAS instruction
               SET @curVAS = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT Note1
                  FROM dbo.OrderDetailRef WITH (NOLOCK)
                  WHERE OrderKey = @cVAS_OrderKey
                     AND OrderLineNumber = @cVAS_OrderLineNo
                     AND StorerKey = @cStorerKey
                     AND ParentSKU = @cSKU
                  ORDER BY 1
               OPEN @curVAS
               FETCH NEXT FROM @curVAS INTO @cVAS_Activity
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @nCount = 1 SET @cErrMsg01 = '1. ' + @cVAS_Activity ELSE
                  IF @nCount = 2 SET @cErrMsg02 = '2. ' + @cVAS_Activity ELSE
                  IF @nCount = 3 SET @cErrMsg03 = '3. ' + @cVAS_Activity ELSE
                  IF @nCount = 4 SET @cErrMsg04 = '4. ' + @cVAS_Activity ELSE
                  IF @nCount = 5 SET @cErrMsg05 = '5. ' + @cVAS_Activity

                  SET @nCount = @nCount + 1

                  FETCH NEXT FROM @curVAS INTO @cVAS_Activity
               END

               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05

               SET @nErrNo = 0
            END
         END
      END
   END
   
Quit:
   
END

GO