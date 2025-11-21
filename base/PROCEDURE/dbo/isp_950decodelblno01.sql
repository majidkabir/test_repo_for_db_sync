SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_950DecodeLBLNo01                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Check label no reuse                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-Jan-2015 1.0  Ung         SOS331539 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_950DecodeLBLNo01]
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
   @b_Success          INT          OUTPUT,
   @n_ErrNo            INT          OUTPUT,
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @c_oFieled01 = ''

   -- Check LabelNo is UCC
   IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND UCCNo = @c_LabelNo)
   BEGIN
      SET @n_ErrNo = 51551
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Label is UCCNo
      GOTO Quit
   END

   -- Check LabelNo is ToID
   IF EXISTS( SELECT 1 
      FROM Receipt R WITH (NOLOCK) 
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @c_StorerKey 
         AND ToID = @c_LabelNo 
         AND FinalizeFlag <> 'Y'
         AND BeforeReceivedQTY > 0)
   BEGIN
      SET @n_ErrNo = 51552
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --LabelUsedInASN
      GOTO Quit
   END

   SET @c_oFieled01 = @c_LabelNo
   SET @n_ErrNo = 0
   SET @c_ErrMsg = ''
   
Quit:

END

GO