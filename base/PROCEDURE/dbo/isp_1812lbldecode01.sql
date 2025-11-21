SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_1812LblDecode01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode UCC No                                               */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-01-2018  1.0  Ung         WMS-3333 Created                        */
/* 07-01-2019  1.1  JHTAN       UCC Not Exists error (JH01)             */  
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_1812LblDecode01]
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

   DECLARE @cActUCCNo      NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @cUCCStatus     NVARCHAR( 1)
   DECLARE @nUCCQTY        INT
   
   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskUOMQTY    INT
   
   DECLARE @cLOCType       NVARCHAR( 10)

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0

   SET @cActUCCNo = @c_LabelNo
   SET @cTaskDetailKey = @c_oFieled10

   -- Get task info
   SELECT
      @cTaskLOT = LOT,
      @cTaskLOC = FromLOC,
      @cTaskID = FromID, 
      @cTaskSKU = SKU, 
      @nTaskQTY = QTY, 
      @nTaskUOMQTY = UOMQTY
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 118352
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END
   
   -- Get LOC info
   SELECT @cLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cTaskLOC

   -- Bulk LOC
   IF @cLOCType = 'OTHER'
   BEGIN
      -- Check double scan
      IF EXISTS( SELECT 1 FROM rdt.rdtFCPLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
      BEGIN
         SET @n_ErrNo = 118351
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC scanned
         RETURN
      END
      
      -- Get UCC record
      SELECT @nRowCount = COUNT( 1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cActUCCNo
       AND StorerKey = @c_Storerkey

      -- Check label scanned is UCC
      IF @nRowCount = 0
      BEGIN
         SET @c_oFieled01 = '' -- SKU
         SET @c_oFieled05 = 0  -- UCC QTY
         SET @c_oFieled08 = '' -- UCC QTY

         SET @n_ErrNo = 118353
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
         RETURN
      END

      -- Check multi SKU UCC
      IF @nRowCount > 1
      BEGIN
         SET @n_ErrNo = 118354
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC
         RETURN
      END

      -- Get UCC info
      SELECT
         @cUCCSKU = SKU,
         @nUCCQTY = QTY,
         @cUCCLOT = LOT,
         @cUCCLOC = LOC,
         @cUCCID = ID,
         @cUCCStatus = Status
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cActUCCNo
         AND StorerKey = @c_Storerkey
/*
      -- Check UCC status
      IF @cUCCStatus NOT IN ('1', '3')
      BEGIN
         SET @n_ErrNo = 118355
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status
         RETURN
      END

      -- Check UCC LOC match
      IF @cTaskLOC <> @cUCCLOC
      BEGIN
         SET @n_ErrNo = 118356
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
         RETURN
      END

      -- Check UCC ID match
      IF @cTaskID <> @cUCCID
      BEGIN
         SET @n_ErrNo = 118357
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
         RETURN
      END

      -- Check UCC Lot match 
      IF @cTaskLot <> @cUCCLot 
      BEGIN
         SET @n_ErrNo = 118358
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOTNotMatch
         RETURN
      END
*/      
      -- Check SKU match
      IF @cTaskSKU <> @cUCCSKU
      BEGIN
         SET @n_ErrNo = 118359
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCSKUNotMatch
         RETURN
      END
      
      -- Check QTY match
      IF @nTaskUOMQTY <> @nUCCQTY
      BEGIN
         SET @n_ErrNo = 118360
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCQTYNotMatch
         RETURN
      END      
/*
      -- Check UCC taken by other task
      IF EXISTS( SELECT TOP 1 1
         FROM UCC WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.CaseID)
         WHERE UCC.StorerKey = @c_StorerKey
            AND PD.StorerKey = @c_StorerKey
            AND UCC.UCCNo = @cActUCCNo
            AND PD.Status > '0'
            AND PD.QTY > 0 )
      BEGIN
         SET @n_ErrNo = 118361
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCTookByOther
         RETURN
      END
*/
      SET @c_oFieled01 = @cUCCSKU
      SET @c_oFieled05 = @nUCCQTY
      --SET @c_oFieled08 = @cActUCCNo (JH01)
   END
   ELSE
      SET @c_oFieled01 = @c_LabelNo
END

GO