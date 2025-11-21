SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispVFL03                                            */
/* Copyright: IDS                                                       */
/* Purpose: Default lottable03                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-02   Ung       1.0   Created                                 */
/* 2014-12-01   Ung       1.1   Performance tuning                      */
/* 2015-02-06   CSCHONG   1.2   Add new lottable06 to 15                */
/*                              and new input parameter (CS01)          */ 
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFL03]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value DATETIME,
	@dt_Lottable05Value DATETIME,
   @c_Lottable06Value  NVARCHAR(30)   = '',
   @c_Lottable07Value  NVARCHAR(30)   = '',
   @c_Lottable08Value  NVARCHAR(30)   = '',
   @c_Lottable09Value  NVARCHAR(30)   = '',
   @c_Lottable10Value  NVARCHAR(30)   = '',
   @c_Lottable11Value  NVARCHAR(30)   = '',
   @c_Lottable12Value  NVARCHAR(30)   = '',
   @dt_Lottable13Value DATETIME       = NULL,
   @dt_Lottable14Value DATETIME       = NULL,
   @dt_Lottable15Value DATETIME       = NULL,
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      DATETIME OUTPUT,
   @dt_Lottable05      DATETIME OUTPUT,
   @c_Lottable06       NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable07       NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable08       NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable09       NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable10       NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable11       NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable12       NVARCHAR(30)   = ''     OUTPUT,
   @dt_Lottable13      DATETIME       = NULL   OUTPUT,
   @dt_Lottable14      DATETIME       = NULL   OUTPUT,
   @dt_Lottable15      DATETIME       = NULL   OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(15) = '',  
   @c_Sourcetype       NVARCHAR(20) = '',  
   @c_LottableLabel    NVARCHAR(20) = '' , 
   @c_type             NVARCHAR(10)   = ''      --(CS01)   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- RDT cycle count
   IF @c_Sourcetype = 'RDTCCOUNT'
   BEGIN
      IF @c_Lottable03Value = ''
         SET @c_Lottable03 = 'W100'
      
      GOTO Quit
   END

   -- RDT UCC receiving
   IF @c_Sourcetype = 'RDTUCCRCV'
   BEGIN
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
      SET @c_Lottable03Value = ''

      -- Get Mobrec info
      SELECT 
         @nFunc = Func, 
         @nStep = Step, 
         @cReceiptKey = V_ReceiptKey, 
         @cUCCNo = I_Field01 --UCC
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE UserName = SUSER_SNAME()
   
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
         @nCount = COUNT( DISTINCT Lottable03), 
         @c_Lottable03Value = MAX( Lottable03)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ExternReceiptKey = @cExternKey
         
      IF @nCount = 1
         SET @c_Lottable03 = @c_Lottable03Value
      ELSE
         SET @c_Lottable03 = ''
   
      GOTO Quit
   END
END

Quit:

GO