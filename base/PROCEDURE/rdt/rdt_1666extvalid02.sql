SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1666ExtValid02                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-01-30  1.0  YeeKung     WMS-11912 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1666ExtValid02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tExtValidate   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cMbolKey       NVARCHAR( 10)
   DECLARE @cPalletID      NVARCHAR( 30)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cMBOLRoute    NVARCHAR( 10)
   DECLARE @cOtherMbolKey  NVARCHAR( 20)  
   DECLARE @cOrderKey      NVARCHAR( 20) 


   -- Variable mapping
   SELECT @cMbolKey = Value FROM @tExtValidate WHERE Variable = '@cMbolKey'
   SELECT @cPalletID = Value FROM @tExtValidate WHERE Variable = '@cPalletID'

   IF @nStep = 1 -- MBOLKey
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cMBOLRoute = ''    
         SELECT TOP 1     
            @cMBOLRoute = route      
         FROM dbo.MBOL WITH (NOLOCK)      
         WHERE MbolKey = @cMbolKey
         AND Status= 0   
    
         IF  ISNULL(@cMBOLRoute,'')=''  
         BEGIN    
            SET @nErrNo = 147851    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Route Empty    
            GOTO Quit    
         END
         
      END
   END

   IF @nStep = 2 -- Pallet
   BEGIN
      SET @cStatus = ''
      SELECT TOP 1 
         @cStatus = Status
      FROM dbo.PALLETDETAIL WITH (NOLOCK)
      WHERE PalletKey = @cPalletID
      ORDER BY 1 

      IF @cStatus <> '9'
      BEGIN
         SET @nErrNo = 147854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet Not Close
         GOTO Quit
      END

      IF @nInputKey = 1 -- ENTER
      BEGIN
         CREATE TABLE #OrdersOnPallet (
            RowRef      INT IDENTITY(1,1) NOT NULL,
            OrderKey    NVARCHAR(10)  NULL)

         DECLARE @curORD CURSOR  
         SET @curORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT UserDefine02
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cPalletID
         AND   Status = '9'
         OPEN @curORD
         FETCH NEXT FROM @curORD INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO #OrdersOnPallet ( OrderKey) VALUES ( @cOrderKey)

            FETCH NEXT FROM @curORD INTO @cOrderKey
         END

         SET @cOtherMbolKey = ''

         SELECT TOP 1 @cOtherMbolKey = MBOLKey
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)
         ORDER BY 1 DESC

         -- Exists in other mbol
         IF @cOtherMbolKey <> ''
         BEGIN
            SET @nErrNo = 147852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Scanned
            GOTO Quit
         END

         SELECT @cMBOLRoute=Route
         FROM MBOL (NOLOCK)
         WHERE MBOLKEY=@cMbolKey

         IF EXISTS(SELECT 1
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)
         WHERE O.route<>@cMBOLRoute)
         BEGIN
            SET @nErrNo = 147853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Route
            GOTO Quit
         END

      END
   END
   Quit:

END

GO