SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispVFL02ForXDock                                    */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable02 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-04-22   Ung       1.0   Created                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFL02ForXDock]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value DATETIME,
	@dt_Lottable05Value DATETIME,
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      DATETIME OUTPUT,
   @dt_Lottable05      DATETIME OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(15) = '',  
   @c_Sourcetype       NVARCHAR(20) = '',  
   @c_LottableLabel    NVARCHAR(20) = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nCount      INT
   DECLARE @nFunc       INT
   DECLARE @nStep       INT
   DECLARE @cUCCNo      NVARCHAR(20)
   DECLARE @cDocType    NVARCHAR(1)
   DECLARE @cStorerKey  NVARCHAR(15)
   DECLARE @cExternKey  NVARCHAR(15)
   DECLARE @cReceiptKey NVARCHAR(10)

   SET @nCount = 0
   SET @cDocType = ''
   SET @cStorerKey = ''
   SET @cExternKey = ''
   SET @c_Lottable02Value = ''
   
   -- Get RDT
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   IF @n_IsRDT <> 1
      GOTO Quit
   
   -- Get Mobrec info
   SELECT TOP 1 
      @nFunc = Func, 
      @nStep = Step, 
      @cReceiptKey = V_ReceiptKey, 
      @cUCCNo = I_Field01 --UCC
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()
   ORDER BY EditDate DESC

   -- Check if UCC receiving module
   IF @@ROWCOUNT <> 1 OR
      @nFunc <> 898 OR  -- UCC receiving
      @nStep <> 6       -- UCC screen
      GOTO Quit

   -- Get Receipt info
   SELECT 
      @cDocType = DocType, 
      @cStorerKey = StorerKey
   FROM Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey

   -- Check if XDock
   IF @cDocType <> 'X'
      GOTO Quit

   -- Get UCC info
   SELECT TOP 1 
      @cExternKey = ExternKey
   FROM UCC WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo
      
   -- Get receipt detail info
   SELECT TOP 1
      @nCount = COUNT( DISTINCT Lottable02), 
      @c_Lottable02Value = MAX( Lottable02)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ExternReceiptKey = @cExternKey
      
   IF @nCount = 1
      SET @c_Lottable02 = @c_Lottable02Value
   ELSE
      SET @c_Lottable02 = ''
END

Quit:

GO