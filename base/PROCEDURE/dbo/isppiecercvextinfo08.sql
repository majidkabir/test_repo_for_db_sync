SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPieceRcvExtInfo08                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Show carton should go to PICK or BULK                       */
/*          1 carton 1 SKU only                                         */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 2020-12-09  1.0  Chermaine    WMS-15615 Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo08]
   @c_ReceiptKey     NVARCHAR(10),
   @c_POKey          NVARCHAR(10),
   @c_ToLOC          NVARCHAR(10),
   @c_ToID           NVARCHAR(18),
   @c_Lottable01     NVARCHAR(18),
   @c_Lottable02     NVARCHAR(18),
   @c_Lottable03     NVARCHAR(18),
   @d_Lottable04     DATETIME,
   @c_StorerKey      NVARCHAR(15),
   @c_SKU            NVARCHAR(20),
   @c_oFieled01      NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nFunc    INT
   DECLARE @nStep    INT
   DECLARE @nInput   INT
   DECLARE @nQTY_AVL INT
   DECLARE @nQTY_RCV INT
   DECLARE @cBUSR4   NVARCHAR( 10)

   -- Get session info
   SELECT 
      @nFunc = Func, 
      @nStep = Step, 
      @nInput = InputKey
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()

   IF @nFunc = 1581 -- Piece receiving
   BEGIN
      IF @nStep = 5 -- SKU
      BEGIN
         IF @nInput = 1 -- ENTER
         BEGIN
            IF @c_SKU <> '' 
            BEGIN
               DECLARE @cPrice NVARCHAR(15)
               SELECT TOP 1 
                  @cPrice = Price
               FROM SKU WITH (NOLOCK) 
               WHERE SKU = @c_SKU

               SET @c_oFieled01 = 'PRICE:' + @cPrice
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO