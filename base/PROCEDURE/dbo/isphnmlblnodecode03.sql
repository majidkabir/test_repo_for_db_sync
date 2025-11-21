SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispHnMLblNoDecode03                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-02-2014  1.0  James       SOS300492 Created                       */
/* 06-08-2015  1.1  James       SOS347381 - Display error msg in        */
/*                              another scn if config turn on (james01) */
/* 02-01-2018  1.2  James       WMS3666 - Add config to control the     */
/*                              decoding method (james01)               */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispHnMLblNoDecode03]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_LblLength             INT, 
           @c_OrderKey              NVARCHAR( 10), 
           @c_SKU                   NVARCHAR( 20), 
           @c_Lottable01            NVARCHAR( 18), 
           @c_Lottable02            NVARCHAR( 18), 
           @c_Lottable03            NVARCHAR( 18), 
           @d_Lottable04            DATETIME, 
           @c_ShowErrMsgInNewScn    NVARCHAR( 1), 
           @n_Func                  INT, 
           @n_Mobile                INT,
           @c_DecodeUCCNo      NVARCHAR( 1)

   DECLARE @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20), @cErrMsg6    NVARCHAR( 20),
           @cErrMsg7    NVARCHAR( 20), @cErrMsg8    NVARCHAR( 20),
           @cErrMsg9    NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20),
           @cErrMsg11   NVARCHAR( 20), @cErrMsg12   NVARCHAR( 20),
           @cErrMsg13   NVARCHAR( 20), @cErrMsg14   NVARCHAR( 20),
           @cErrMsg15   NVARCHAR( 20) 

   SELECT @n_Func = Func, @n_Mobile = Mobile FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUSER_SNAME()

   SET @c_DecodeUCCNo = rdt.RDTGetConfig( @n_Func, 'DecodeUCCNo', @c_Storerkey)

   IF @c_DecodeUCCNo = '1'
      SET @c_LabelNo = RIGHT( @c_LabelNo, LEN(@c_LabelNo) - 2)

   SET @c_ShowErrMsgInNewScn = rdt.RDTGetConfig( @n_Func, 'ShowErrMsgInNewScn', @c_Storerkey)
   IF @c_ShowErrMsgInNewScn = '0'
      SET @c_ShowErrMsgInNewScn = ''      

           
   SET @n_ErrNo = 0
   SET @c_OrderKey = @c_ReceiptKey

   IF ISNULL( @c_OrderKey, '') = ''
   BEGIN
      SET @c_ErrMsg = 'Invalid Order'
      GOTO Quit
   END

   SET @n_LblLength = 0
   SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))

   IF @n_LblLength = 0
   BEGIN
      SET @c_ErrMsg = 'Invalid SKU'   --Return Error
      /*
      IF @c_ShowErrMsgInNewScn = '1' -- (james01)
      BEGIN
         SET @cErrMsg1 = @c_ErrMsg
 SET @cErrMsg2 = ''
         SET @cErrMsg3 = ''
         SET @n_ErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @n_Mobile, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @n_ErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END         
      END
      */
      GOTO Quit
   END
   
   SET @c_SKU = SUBSTRING( RTRIM( @c_LabelNo), 3, 13) -- SKU
   SET @c_Lottable02 = SUBSTRING( RTRIM( @c_LabelNo), 16, 12) -- Lottable02
   SET @c_Lottable02 = RTRIM( @c_Lottable02) + '-' -- Lottable02
   SET @c_Lottable02 = RTRIM( @c_Lottable02) + SUBSTRING( RTRIM( @c_LabelNo), 28, 2) -- Lottable02

   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @c_Storerkey
                   AND   OrderKey = @c_OrderKey
                   AND   SKU = @c_SKU
                   AND   [Status] < '9')
   BEGIN
      SET @c_ErrMsg = 'Invalid SKU'   --Return Error
      /*
      IF @c_ShowErrMsgInNewScn = '1' -- (james01)
      BEGIN
         SET @cErrMsg1 = @c_ErrMsg
         SET @cErrMsg2 = ''
         SET @cErrMsg3 = ''
         SET @n_ErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @n_Mobile, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @n_ErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END         
      END
      */
      GOTO Quit
   END

	
   IF NOT EXISTS ( SELECT 1 FROM dbo.LotAttribute WITH (NOLOCK) 
                   WHERE StorerKey = @c_StorerKey
                   AND   SKU = @c_SKU
                   AND   Lottable02 = @c_Lottable02)
   BEGIN
      SET @c_ErrMsg = 'Invalid Lot02'   --Return Error
      GOTO Quit
   END

   SET @c_oFieled01 = @c_SKU
   SET @c_oFieled02 = @c_Lottable02

   Quit:  


END -- End Procedure


GO