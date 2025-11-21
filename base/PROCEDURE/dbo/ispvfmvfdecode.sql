SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispVFMVFDecode                                      */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-05-2015  1.0  Ung         SOS340175. Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFMVFDecode]
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

   DECLARE @nRowCount      INT

   DECLARE @cUCCNo         NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @nUCCQTY        INT

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @nSystemQTY     INT
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cLoseUCC       NVARCHAR( 1)

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0
   
   SET @cDropID = @c_oFieled09
   SET @cTaskDetailKey = @c_oFieled10

   -- Get task info
   SELECT 
      @cLOT = LOT, 
      @cLOC = FromLOC,
      @cID = FromID, 
      @nSystemQTY = SystemQTY
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 54401
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END

   -- Get LOC info
   SELECT @cLoseUCC = LoseUCC FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

   IF @cLoseUCC = '1' -- DPP
   BEGIN
      SET @c_oFieled01 = @c_LabelNo -- SKU
      SET @c_oFieled05 = 0          -- UCC QTY
      SET @c_oFieled08 = ''         -- UCC QTY
      
      RETURN
   END
   ELSE
   BEGIN
      -- Get UCC record
      SELECT @nRowCount = COUNT( 1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @c_LabelNo
         AND StorerKey = @c_Storerkey
         AND Status = '1'
      
      -- Check label scanned is UCC
      IF @nRowCount = 0
      BEGIN
         SET @c_oFieled01 = '' -- SKU
         SET @c_oFieled05 = 0  -- UCC QTY
         SET @c_oFieled08 = '' -- UCC QTY
   
         SET @n_ErrNo = 54402
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
         RETURN
      END
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @n_ErrNo = 54403
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC
      RETURN
   END

   -- Get UCC info
   SELECT 
      @cUCCNo = UCCNo, 
      @cUCCSKU = SKU, 
      @nUCCQTY = QTY, 
      @cUCCLOT = LOT,
      @cUCCLOC = LOC, 
      @cUCCID = ID
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE UCCNo = @c_LabelNo 
      AND StorerKey = @c_Storerkey
      AND Status = '1'

   -- Check UCC LOC match
   IF @cLOC <> @cUCCLOC
   BEGIN
      SET @n_ErrNo = 54404
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
      RETURN
   END

   -- Check UCC ID match
   IF @cID <> @cUCCID
   BEGIN
      SET @n_ErrNo = 54405
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      RETURN
   END

   -- Check UCC LOT match
   IF @cLOT <> @cUCCLOT
   BEGIN
      SET @n_ErrNo = 54406
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOTNotMatch
      RETURN
   END

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cUCCNo)
   BEGIN
      SET @n_ErrNo = 54407
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC scanned
      RETURN
   END
   
   -- Check over pick (means existing scanned UCC already fulfill QTY, should not allow new scan UCC)
   IF (SELECT ISNULL( SUM( QTY), 0) 
      FROM rdt.rdtRPFLog WITH (NOLOCK) 
      WHERE TaskDetailKey = @cTaskDetailKey 
         AND DropID = @cDropID) > @nSystemQTY
   BEGIN
      SET @n_ErrNo = 54408
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Over replenish
      RETURN
   END
   
   -- Ignore full pallet replen, pallet ID could scan more then once (FromID-->ToLOC ESC FromID-->ToLOC...)
   IF @cDropID = '' 
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND DropID = @cUCCNo)
         RETURN
   END

   SET @c_oFieled01 = @cUCCSKU
   SET @c_oFieled05 = @nUCCQTY
   SET @c_oFieled08 = @cUCCNo
   
END -- End Procedure


GO