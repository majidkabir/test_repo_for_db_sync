SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_830ExtInfo02                                    */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 21-11-2018  1.0  James       WMS-6862 Created                        */  
/* 27-12-2020  1.1  YeeKung     WMS-15995 Add PickZone(yeekung01)       */
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_830ExtInfo02]  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nAfterStep    INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cPickSlipNo   NVARCHAR( 10), 
   @cPickZone     NVARCHAR( 10), 
   @cSuggLOC      NVARCHAR( 10),  
   @cLOC          NVARCHAR( 10),  
   @cDropID       NVARCHAR( 20),  
   @cSKU          NVARCHAR( 20),  
   @cLottable01   NVARCHAR( 18),  
   @cLottable02   NVARCHAR( 18),  
   @cLottable03   NVARCHAR( 18),  
   @dLottable04   DATETIME,  
   @dLottable05   DATETIME,  
   @cLottable06   NVARCHAR( 30),  
   @cLottable07   NVARCHAR( 30),  
   @cLottable08   NVARCHAR( 30),  
   @cLottable09   NVARCHAR( 30),  
   @cLottable10   NVARCHAR( 30),  
   @cLottable11   NVARCHAR( 30),  
   @cLottable12   NVARCHAR( 30),  
   @dLottable13   DATETIME,  
   @dLottable14   DATETIME,  
   @dLottable15   DATETIME,  
   @nTaskQTY      INT,  
   @nQTY          INT,  
   @cToLOC        NVARCHAR( 10),  
   @cOption       NVARCHAR( 1),  
   @cExtendedInfo NVARCHAR( 20) OUTPUT,  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cOrderKey NVARCHAR( 10)  
   DECLARE @cConsigneeKey NVARCHAR( 15)  
   DECLARE @cSUSR5 NVARCHAR( 20)  
   DECLARE @cUserName   NVARCHAR( 18)  
   DECLARE @nScan       INT  
   DECLARE @nTotal      INT  
  
   SELECT @cUserName = UserName  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   IF @nFunc = 830 -- PickSKU  
   BEGIN  
      IF @nAfterStep = 2 -- LOC  
      BEGIN  
         SET @cExtendedInfo = ''  
  
         -- Get PickSlip info  
         SELECT @cOrderKey = OrderKey FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo  
           
         -- Get order info  
         DECLARE @dDeliveryDate DATETIME  
         DECLARE @cCompany NVARCHAR( 45)  
         SELECT   
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
                     SET @cExtendedInfo = '[@@]'  
               END  
            END  
         END  
  
         SET @cExtendedInfo = LEFT( @cExtendedInfo + @cCompany, 20)  
      END  
  
      IF @nAfterStep = 10 -- Capture case id  
      BEGIN  
         SET @cExtendedInfo = ''  
         SET @nScan = 0  
         SET @nTotal = 0  
  
         -- Calc statistic  
         EXEC rdt.rdt_877GetStatSP01 @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey  
            ,@cOrderKey  
            ,@nScan     OUTPUT  
            ,@nTotal    OUTPUT  
            ,''  
  
         SET @cExtendedInfo = @nScan/@nTotal  
      END  
   END  
  
Quit:  
  
END  

GO