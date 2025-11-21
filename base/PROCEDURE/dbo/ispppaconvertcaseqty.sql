SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispPPAConvertCaseQTY                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Convert system QTY to and from display QTY                  */
/*                                                                      */
/* Called from: rdt_PostPickAudit_GetStat/ExtendedInfo                  */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-05-2019  1.0  James       WMS7983. Created                        */
/************************************************************************/

CREATE PROC [dbo].[ispPPAConvertCaseQTY]
   @cType         NVARCHAR( 10), 
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Get SKU info
   DECLARE @fCaseCnt    FLOAT
   DECLARE @nCaseCnt    INT
   DECLARE @nFunc       INT
   DECLARE @nStep       INT
   DECLARE @nInputKey   INT
   DECLARE @nPQty       INT
   DECLARE @nMQty       INT
   DECLARE @cPUOM       NVARCHAR( 10)
   DECLARE @cPQty       NVARCHAR( 5)
   DECLARE @cMQty       NVARCHAR( 5)

   SELECT @nFunc = Func,
          @nStep = Step,
          @nInputKey = InputKey,
          @cPQty = I_Field09,
          @cMQty = I_Field10,
          @cPUOM = V_UOM
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()

   IF @nFunc = 855
   BEGIN
      SET @fCaseCnt = 0
      SELECT @fCaseCnt = CaseCnt
      FROM dbo.SKU S WITH (NOLOCK)
      JOIN dbo.Pack P WITH (NOLOCK) ON ( S.PackKey = P.PackKey)
      WHERE S.StorerKey = @cStorerKey
      AND   S.SKU = @cSKU

      IF ISNULL(@fCaseCnt, '') = 0
         RETURN

      IF @nStep IN ( 1, 2)
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @nCaseCnt = @fCaseCnt

            IF @cType = 'ToDispQTY'
               SET @nQTY = @nQTY / @nCaseCnt

            IF @cType = 'ToBaseQTY'
            BEGIN
               IF ((@nQTY * @nCaseCnt) % @nCaseCnt) <> 0
                  SET @nQTY = -1 -- Error convert to base qty
               ELSE
                  SET @nQTY = @nQTY * @nCaseCnt
            END
         END   -- @nInputKey = 1
      END   -- @nStep = 2

      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @nMQty = CAST( @cMQty AS INT)

            -- Calc total QTY in master UOM
            SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
            SET @nQTY = @nQTY + @nMQTY
         END

         IF @nInputKey = 0
         BEGIN
            SET @nCaseCnt = @fCaseCnt

            IF @cType = 'ToDispQTY'
               SET @nQTY = @nQTY / @nCaseCnt

            IF @cType = 'ToBaseQTY'
            BEGIN
               IF ((@nQTY * @nCaseCnt) % @nCaseCnt) <> 0
                  SET @nQTY = -1 -- Error convert to base qty
               ELSE
                  SET @nQTY = @nQTY * @nCaseCnt
            END
         END   -- @nInputKey = 1
      END   -- @nStep = 2
   END   -- @nFunc = 855
   
   QUIT:
END -- End Procedure

GO