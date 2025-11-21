SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593OutPLWeight01                                      */
/*                                                                            */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author           Purposes                                  */
/* 2024-05-31 1.0  Xiaotong Guan     UWP-21389 Created                        */
/******************************************************************************/

CREATE     PROC [RDT].[rdt_593OutPLWgt01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- PalletWeight
   @cParam2    NVARCHAR(20),  -- PalletQty
   @cParam3    NVARCHAR(20),  -- Mbol Key
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success      INT
   DECLARE @n_Err          INT
   DECLARE @c_ErrMsg       NVARCHAR( 250)

   DECLARE @cPalletWeight  NVARCHAR( 20)
   DECLARE @cPalletQty     NVARCHAR( 20)
   DECLARE @cMbolKey       NVARCHAR( 20)
   DECLARE @cStatus        NVARCHAR( 20)
   DECLARE @cMbolDetailNo  NVARCHAR( 20)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @c_weight       FLOAT
   DECLARE @c_RemainWeight FLOAT


   -- Parameter mapping
   SET @cPalletWeight = @cParam1
   SET @cPalletQty    = @cParam2
   SET @cMbolKey      = @cParam3

   -- Check blank
   IF @cPalletWeight = ''
   BEGIN
      SET @nErrNo = 218751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit
   END

   IF @cPalletQty = '' OR TRY_CAST(@cPalletQty as INT) IS NULL OR @cPalletQty = 0
   BEGIN
      SET @nErrNo = 218752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit
   END

   IF @cMbolKey = ''
   BEGIN
      SET @nErrNo = 218753
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit
   END
   
   -- Mbol Key exists
   SELECT @cStatus = Status
   FROM dbo.MBOL WITH (NOLOCK)
   WHERE MbolKey = @cMbolKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 218754
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol Not Exists
      GOTO Quit
   END

   IF @cStatus = '9'
   BEGIN
      SET @nErrNo = 218755
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol Shipped
      GOTO Quit
   END

   -- PalletQty = Count of MbolDetail
   SELECT @cMbolDetailNo = count(MbolKey)
   FROM dbo.MBOLDETAIL WITH(NOLOCK)
   WHERE MbolKey = @cMbolKey

   IF @cPalletQty <> @cMbolDetailNo
   BEGIN
      SET @nErrNo = 218756
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')   ---- Bad Pallet Qty
      GOTO Quit
   END



   -- Insert Ave Pallet Weight

   IF @cPalletQty = 1
   BEGIN
      SELECT @c_weight = @cPalletWeight
      SELECT @c_RemainWeight = @cPalletWeight
   END
   ELSE
   BEGIN
      SELECT @c_weight = FLOOR(CAST(@cPalletWeight AS FLOAT) / CAST(@cPalletQty AS INT ))

      SELECT @c_RemainWeight = @c_weight + (@cPalletWeight - @c_weight * @cPalletQty)
   END


   UPDATE MBOLDETAIL  SET Weight = @c_weight 
   WHERE MbolKey = @cMbolKey

   UPDATE MBOLDETAIL  SET Weight = @c_RemainWeight 
   WHERE MbolKey = @cMbolKey AND MbolLineNumber = '00001'


   Quit:

END -- END SP

GO