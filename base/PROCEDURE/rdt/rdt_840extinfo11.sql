SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo11                                    */
/* Copyright: MAERSK                                                    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-03-31 1.0  James      WMS-22084. Created                        */
/* 2023-10-11 1.1  James      WMS-23401 Add company display (james01)   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtInfo11] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cStorerkey    NVARCHAR( 15),
   @cOrderKey     NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10),
   @cTrackNo      NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @nCartonNo     INT,
   @cExtendedInfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cConsigneeKey  NVARCHAR( 15)
   DECLARE @cBillToKey     NVARCHAR( 15)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cC_Company     NVARCHAR( 30)
   DECLARE @cVas           NVARCHAR( 3) = ''
   DECLARE @cBUSR9         NVARCHAR( 30)
   DECLARE @cItemClass     NVARCHAR( 10)
   DECLARE @cLong          NVARCHAR( 30)
   
   DECLARE @cDropIDCheck         NVARCHAR( 1)   --TSY01
   DECLARE @cDropID              NVARCHAR( 50)  --TSY01
   DECLARE @nTTLPickedDropID     INT = 0        --TSY01
   DECLARE @nTTLPackedDropID     INT = 0        --TSY01
   DECLARE @cDropIDPickPackStat  NVARCHAR( 50)  --TSY01
   DECLARE @c_InField02          NVARCHAR( 60)  --TSY01

   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF 3 IN ( @nStep, @nAfterStep) -- SKU
      BEGIN
         SELECT @cFacility = Facility
               ,@cDropID = V_CaseID      --TSY01
               ,@c_InField02 = I_Field02 --TSY01
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

       SELECT 
         @cBillToKey = BillToKey,
         @cConsigneeKey = ConsigneeKey
       FROM dbo.ORDERS WITH (NOLOCK)
       WHERE OrderKey = @cOrderKey

      SELECT 
         @cBUSR9 = BUSR9,
         @cItemClass = itemclass
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
      AND   SKU = @cSKU

      IF EXISTS( SELECT TOP 1 1 
                 FROM dbo.CODELKUP WITH (NOLOCK) 
                 WHERE Listname = 'LVSHANGER' 
                 AND   Code = @cBillToKey
                 AND   Short = @cItemClass)
      BEGIN
         IF EXISTS( SELECT TOP 1 1 
                    FROM dbo.CODELKUP WITH (NOLOCK) 
                    WHERE Listname = 'LVSHANGER' 
                    AND   Code = @cBillToKey
                    AND   Short = @cItemClass
                    AND   Notes = @cBUSR9)
         BEGIN
            SELECT @cLong = Long 
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE Listname = 'LVSHANGER' 
            AND   Code = @cBillToKey
            AND   Short = @cItemClass
            AND   Notes = @cBUSR9
            
            IF ISNULL( @cLong, '') = ''
               SET @cVas = '(H)'
            ELSE
            	SET @cVas = '(' + LEFT( @cLong, 1) + ')'
         END
         ELSE
         	SET @cVas = '(H)'
      END

      IF EXISTS( SELECT 1   
                 FROM dbo.Storer WITH (NOLOCK)  
                 WHERE StorerKey = @cBillToKey  
                 AND   [type] = '2'  
                 AND   Facility = @cFacility
                 AND   ( LabelPrice = 'Y' OR SUSR1 = 'Y' OR SUSR2 = 'Y')) AND @cVas = ''
         SET @cVas = '(V)'
         

 
      SELECT @cC_Company = LEFT( Company, 9)
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cConsigneeKey
      
       --TSY01 START DROPID DISPLAY
      SET @cDropIDCheck = rdt.RDTGetConfig( @nFunc, 'CHKDropIDSKUQTY', @cStorerKey)
      IF @cDropIDCheck = 1
      BEGIN
         SET @nTTLPickedDropID = 0
         SET @nTTLPackedDropID = 0

         IF @nStep = 1 AND @nAfterStep = 3
         BEGIN
            SET @cDropID = @c_InField02
         END

         SELECT @nTTLPickedDropID = SUM(QTY)
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   DROPID = @cDropID

         SELECT @nTTLPackedDropID = SUM(QTY)
         FROM dbo.PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   RefNo2 = @cDropID

         SET @cDropIDPickPackStat = CAST(@nTTLPackedDropID AS NVARCHAR) + '/' + CAST(@nTTLPickedDropID AS NVARCHAR)
         SET @cExtendedInfo = LEFT( @cDropIDPickPackStat + ' ' + @cC_Company , 17) + @cVas
      END
       --TSY01 END DROPID DISPLAY
      END
   END

GO