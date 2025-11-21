SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPieceRcvExtInfo05                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Show carton should go to PICK or BULK                       */
/*          1 carton 1 SKU only                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2018-01-10  1.0  Ung         WMS-3651 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo05]
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

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nStep = 5 -- SKU
      BEGIN
         IF @nInput = 1 -- ENTER
         BEGIN
            IF @c_SKU <> '' AND @c_ToID <> ''
            BEGIN
               /*
                  Check 1st piece in carton (ToID)
                  1 carton only 1 SKU
                  1 carton only go to 1 putawayzone
               */
               DECLARE @cPutawayZone NVARCHAR( 10)
               SELECT TOP 1 
                  @cPutawayZone = UserDefine10
               FROM ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @c_ReceiptKey 
                  AND ToID = @c_ToID
                  AND SKU = @c_SKU
                  AND BeforeReceivedQTY > 0
                  AND ISNULL( UserDefine10, '') <> ''

               -- Carton calculated before. Show the PutawayZone
               IF @@ROWCOUNT = 1
               BEGIN
                  SET @c_oFieled01 = @cPutawayZone
                  GOTO Quit
               END
               ELSE
               BEGIN
                  -- Get SKU info
                  SELECT @cBUSR4 = LEFT( BUSR4, 5) FROM SKU WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU
            
                  -- Check safety QTY (min QTY)
                  IF rdt.rdtIsValidQTY( @cBUSR4, 0) = 0
                  BEGIN
                     SET @c_oFieled01 = 'SETUP SAFETY QTY'
                     GOTO Quit
                  END
                  
                  -- Check inventory
                  SELECT @nQTY_AVL = ISNULL( SUM( QTY-QTYAllocated-QTYPicked-QTYReplen), 0)
                  FROM LOTxLOCxID WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey 
                     AND SKU = @c_SKU
                  
                  -- Check previously received carton
                  SELECT @nQTY_RCV = ISNULL( SUM( BeforeReceivedQTY), 0)
                  FROM ReceiptDetail WITH (NOLOCK) 
                  WHERE ReceiptKey = @c_ReceiptKey 
                     AND TOID <> ''
                     AND ToID <> @c_ToID
                     AND SKU = @c_SKU
                     AND BeforeReceivedQTY > 0
                  
                  IF (@nQTY_AVL + @nQTY_RCV) >= CAST( @cBUSR4 AS INT)
                     SET @c_oFieled01 = 'BUFFER'
                  ELSE
                     SET @c_oFieled01 = 'PICK'
                     
               END
            END
         END
      END
   END

Quit:

END

GO