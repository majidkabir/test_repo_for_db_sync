SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtInfo03                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-03-08   Ung       1.0   WMS-4221 Created                        */
/* 2018-07-10   Ung       1.1   Fix [#] should link to SKU              */
/* 2018-08-31   Ung       1.2   WMS-5943 ExternOrderKey                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtInfo03]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cConsigneeKey  NVARCHAR( 15)
   DECLARE @cSUSR5         NVARCHAR( 20)
   DECLARE @dDeliveryDate  DATETIME

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nAfterStep = 2   -- FROM LOC
      BEGIN
         SET @cExtendedInfo1 = ''

         -- Get task info
         SELECT @cOrderKey = OrderKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         
         -- Get order info
         DECLARE @cCompany NVARCHAR( 45)
         SELECT 
            @cStorerKey = StorerKey, 
            @cConsigneeKey = ConsigneeKey, 
            @dDeliveryDate = DeliveryDate, 
            @cCompany = C_Company
         FROM Orders O WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         -- Get consignee info
         SELECT @cSUSR5 = SUSR5 FROM Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey
         
         IF @cSUSR5 = '@@'
         BEGIN
            -- Order contain consignee SKU
            IF EXISTS( SELECT TOP 1 1 
               FROM Orders O WITH (NOLOCK)
                  JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
                  JOIN ConsigneeSKU CS WITH (NOLOCK) ON (OD.StorerKey = CS.StorerKey AND OD.SKU = CS.SKU AND CS.ConsigneeKey = O.ConsigneeKey)
               WHERE O.OrderKey = @cOrderKey)
            BEGIN
               -- Get holiday info
               DECLARE @cHolidayKey NVARCHAR( 10)
               SELECT @cHolidayKey = ISNULL( HolidayKey, '')
               FROM StorerSODefault WITH (NOLOCK)
               WHERE StorerKey = @cConsigneeKey
               
               IF @cHolidayKey <> ''
               BEGIN
                  DECLARE @dToday DATETIME
                  SET @dToday = DATEADD( DD, DATEDIFF( DD, 0, GETDATE()), 0) -- Strip off time portion
                  
                  -- Get holiday in between today and delivery date
                  DECLARE @nHoliday INT
                  SELECT @nHoliday = COUNT(1)
                  FROM HolidayHeader HH WITH (NOLOCK)
                     JOIN HolidayDetail HD WITH (NOLOCK) ON (HH.HolidayKey = HD.HolidayKey)
                  WHERE HD.HolidayKey = @cHolidayKey
                     AND HolidayDate BETWEEN @dToday AND @dDeliveryDate

                  IF DATEDIFF( DD, @dToday, @dDeliveryDate) - @nHoliday > 1
                     SET @cExtendedInfo1 = '[@@]'
               END
            END
         END
         
         SET @cExtendedInfo1 = LEFT( @cExtendedInfo1 + @cCompany, 20)
      END
      
      IF @nAfterStep = 3   -- FROM ID
      BEGIN
         DECLARE @cExternOrderKey NVARCHAR(30)
         
         -- Get task info
         SELECT @cOrderKey = OrderKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         
         -- Get order info
         SELECT 
            @cExternOrderKey = ExternOrderKey, 
            @dDeliveryDate = DeliveryDate
         FROM Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         SET @cExtendedInfo1 = RIGHT( RTRIM( @cExternOrderKey), 9) + '/' + CONVERT( NVARCHAR(8), @dDeliveryDate, 112)
      END
      
      IF @nAfterStep = 4   -- SKU, QTY
      BEGIN
         -- Get task info
         DECLARE @cSKU        NVARCHAR(20)
         DECLARE @cUDF01      NVARCHAR(60)
         DECLARE @cUDF02      NVARCHAR(60)
         DECLARE @cUDF03      NVARCHAR(60)
         DECLARE @cUDF04      NVARCHAR(60)
         DECLARE @cUDF05      NVARCHAR(60)
         DECLARE @cAreaKey    NVARCHAR(10)
         DECLARE @nQTY        INT

         SET @cExtendedInfo1 = ''
         
         -- Get task info
         SELECT 
            @cAreaKey = AreaKey,
            @cStorerKey = StorerKey, 
            @cSKU = SKU
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey
         
         -- Get order info
         SELECT TOP 1 @cOrderKey = OrderKey FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         SELECT TOP 1 @cConsigneeKey = ConsigneeKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Get SKU indicator
         IF EXISTS( SELECT TOP 1 1
            FROM OrderDetail WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND ISNULL( UserDefine05, '') <> '')
         BEGIN
            SET @cExtendedInfo1 = '[#]'
         END    
         
         -- Get consignee SKU info
         SELECT 
            @cUDF01 = UDF01, 
            @cUDF02 = UDF02, 
            @cUDF03 = UDF03,
            @cUDF04 = UDF04,
            @cUDF05 = UDF05
         FROM ConsigneeSKU WITH (NOLOCK)
         WHERE ConsigneeKey = @cConsigneeKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
         
         IF @cUDF01 <> '' OR 
            @cUDF02 <> '' OR 
            @cUDF03 <> '' 
         BEGIN
            SET @cExtendedInfo1 = @cExtendedInfo1 + '[**]'
         END
         
         -- Get SKU to pick (in multiple tasks), to prevent split same SKU into 2 pallets
         IF EXISTS( SELECT TOP 1 1
            FROM TaskDetail WITH (NOLOCK)
            WHERE TaskType = 'FCP'
               AND OrderKey = @cOrderKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND AreaKey = @cAreaKey
               AND TaskDetailKey <> @cTaskdetailKey)
         BEGIN
            SELECT @nQTY = ISNULL( SUM( QTY), 0)
            FROM TaskDetail WITH (NOLOCK)
            WHERE TaskType = 'FCP'
               AND OrderKey = @cOrderKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND AreaKey = @cAreaKey
            
            SET @cExtendedInfo1 = @cExtendedInfo1 + '[TTL:' + CAST( @nQTY AS NVARCHAR(10)) + ']'
         END
         
         -- Get consignee info
         SELECT @cSUSR5 = SUSR5 FROM Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey

         IF @cSUSR5 <> '@@'
         BEGIN
            IF @cSUSR5 = '!!'
               SET @cExtendedInfo1 = @cExtendedInfo1 + 
                  LEFT( @cUDF01, 1) + 
                  LEFT( @cUDF02, 1) + 
                  LEFT( @cUDF03, 1) + 
                  LEFT( @cUDF04, 1) + 
                  LEFT( @cUDF05, 1)
            ELSE
               IF @cUDF01 <> '' AND 
                  @cUDF02 <> '' AND 
                  @cUDF03 <> '' AND 
                  @cUDF04 <> '' AND 
                  @cUDF05 <> '' 
                  SET @cExtendedInfo1 = @cExtendedInfo1 + '[**]'
         END
         
      END
   END
END

GO