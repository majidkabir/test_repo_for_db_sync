SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_RCM_ADJ_CPV                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 03-10-2018 1.0  Ung       WMS-6149 Created                           */
/* 07-03-2019 1.1  ChewKP    Changes.                                   */
/* 08-04-2019 1.2  Ung       WMS-6149 Bug fix                           */
/************************************************************************/

CREATE PROC [dbo].[isp_RCM_ADJ_CPV] (
   @c_AdjustmentKey	NVARCHAR(10), 
   @b_success	      INT           OUTPUT, 
   @n_err	         INT           OUTPUT,
   @c_errmsg	      NVARCHAR(225) OUTPUT, 
   @c_code	         NVARCHAR(30) = ''
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount        INT
   DECLARE @nRowRef           INT   
   DECLARE @cADJLineNo        NVARCHAR(5)
   DECLARE @cNewADJLineNo     NVARCHAR(10)
   DECLARE @cOrgADJLineNo     NVARCHAR(10)
   DECLARE @cParentSKU        NVARCHAR(20)
   DECLARE @cLottable07       NVARCHAR(30)
   DECLARE @cLottable08       NVARCHAR(30)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cLOC              NVARCHAR(10)
   DECLARE @cID               NVARCHAR(18)
   DECLARE @cMasterLOT        NVARCHAR(60)
   DECLARE @cFinalizedFlag    NVARCHAR(1)
   DECLARE @cUserDefine10     NVARCHAR(10)
   DECLARE @dExternLottable04 DATETIME
   DECLARE @nQTY_ADJ          INT
   DECLARE @nQTY_LLI          INT
   DECLARE @curDTL CURSOR

   DECLARE @n_continue int,  
           @n_starttcnt int, 
           @c_StorerKey nvarchar( 15)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0   

   SELECT 
      @c_StorerKey = StorerKey, 
      @cFinalizedFlag = FinalizedFlag, 
      @cUserDefine10 = UserDefine10
   FROM Adjustment WITH (NOLOCK) 
   WHERE AdjustmentKey = @c_AdjustmentKey

   -- Adjustment ready for alloc
   IF @cFinalizedFlag = 'N' AND 
      @cUserDefine10 = 'PENDALLOC'
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction

      -- Loop AdjustmentDetail
      SET @curDTL = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU, AdjustmentLineNumber, ABS( QTY), Lottable07, Lottable08    
         FROM AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @c_AdjustmentKey
            AND StorerKey = @c_StorerKey
            AND QTY < 0
            AND LOT = ''
         ORDER BY AdjustmentLineNumber
      OPEN @curDTL 
      FETCH NEXT FROM @curDTL INTO @cParentSKU, @cADJLineNo, @nQTY_ADJ, @cLottable07, @cLottable08    
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get extern expiry date
         SET @cMasterLOT = @cLottable07 + @cLottable08
         SELECT @dExternLottable04 = ExternLottable04
         FROM ExternLotAttribute WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
            AND SKU = @cParentSKU
            AND ExternLOT = @cMasterLOT
         
         SET @cOrgADJLineNo = @cADJLineNo
         
         -- Find stock
         WHILE @nQTY_ADJ > 0
         BEGIN
            -- Get available stock
            SELECT TOP 1 
               @cLOT = LLI.LOT, 
               @cLOC = LLI.LOC,  
               @cID  = LLI.ID, 
               @nQTY_LLI = LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @c_StorerKey
               AND LLI.SKU = @cParentSKU
               AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen > 0
               -- AND LA.Lottable04 = @dExternLottable04
               AND LA.Lottable07 = @cLottable07
               AND LA.Lottable08 = @cLottable08
               AND LOC.LocationFlag <> 'HOLD'

            IF @@ROWCOUNT = 0
            BEGIN  
               -- select @cParentSKU '@cParentSKU', @dExternLottable04 '@dExternLottable04', @cLottable07 '@cLottable07', @cLottable08 '@cLottable08'
               SET @n_Continue = 3  
               SET @n_Err = 131551  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cOrgADJLineNo AS NVARCHAR(5)) + ' : NO stock. (isp_RCM_ADJ_CPV)'      
               GOTO QUIT_SP  
            END

            -- Adj is exact match or less
            IF @nQTY_ADJ <= @nQTY_LLI
            BEGIN
               UPDATE AdjustmentDetail SET
                  LOT = @cLOT, 
                  LOC = @cLOC, 
                  ID = @cID, 
                  Lottable04 = @dExternLottable04, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE AdjustmentKey = @c_AdjustmentKey
                  AND AdjustmentLineNumber = @cADJLineNo
               IF @@ERROR <> 0
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 131552  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cADJLineNo AS NVARCHAR(5)) + 'Update AdjustmentDetail fail. (isp_RCM_ADJ_CPV)'      
                  GOTO QUIT_SP  
               END

               -- Book the stock
               UPDATE LOTxLOCxID SET
                  QTYReplen = QTYReplen + @nQTY_ADJ, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
               IF @@ERROR <> 0
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 131553  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cADJLineNo AS NVARCHAR(5)) + 'Update LOTxLOCxID fail. (isp_RCM_ADJ_CPV)'      
                  GOTO QUIT_SP  
               END
               
               SET @nQTY_ADJ = 0
            END
            
            -- Adj have more
            ELSE IF @nQTY_ADJ > @nQTY_LLI
            BEGIN
               -- Get new AdjustmentLineNumber
               SELECT @cNewADJLineNo = RIGHT( '00000' + CAST( CAST( MAX( AdjustmentLineNumber) AS INT) + 1 AS NVARCHAR(5)), 5)
               FROM AdjustmentDetail WITH (NOLOCK)
               WHERE AdjustmentKey = @c_AdjustmentKey
               
               -- Split new AdjustmentDetail to hold the balance
               INSERT INTO AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, ID, ReasonCode, UOM, PackKey, Lottable07, Lottable08, QTY)
               SELECT AdjustmentKey, @cNewADJLineNo, StorerKey, SKU, LOC, LOT, ID, ReasonCode, UOM, PackKey, Lottable07, Lottable08, -(@nQTY_ADJ - @nQTY_LLI)
               FROM AdjustmentDetail WITH (NOLOCK)
               WHERE AdjustmentKey = @c_AdjustmentKey
                  AND AdjustmentLineNumber = @cADJLineNo
               IF @@ERROR <> 0    
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 131554  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cADJLineNo AS NVARCHAR(5)) + 'Update AdjustmentDetail fail. (isp_RCM_ADJ_CPV)'      
                  GOTO QUIT_SP  
               END
               
               -- Reduce original
               UPDATE AdjustmentDetail SET
                  LOT = @cLOT, 
                  LOC = @cLOC, 
                  ID = @cID, 
                  QTY = -@nQTY_LLI, 
                  Lottable04 = @dExternLottable04, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE AdjustmentKey = @c_AdjustmentKey
                  AND AdjustmentLineNumber = @cADJLineNo
               IF @@ERROR <> 0
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 131555  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cADJLineNo AS NVARCHAR(5)) + 'Update AdjustmentDetail fail. (isp_RCM_ADJ_CPV)'      
                  GOTO QUIT_SP  
               END

               -- Book the stock
               UPDATE LOTxLOCxID SET
                  QTYReplen = QTYReplen + @nQTY_LLI, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
               IF @@ERROR <> 0
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_Err = 131553  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cADJLineNo AS NVARCHAR(5)) + 'Update LOTxLOCxID fail. (isp_RCM_ADJ_CPV)'      
                  GOTO QUIT_SP  
               END

               SET @nQTY_ADJ = @nQTY_ADJ - @nQTY_LLI
               
               -- Point to new line
               SET @cADJLineNo = @cNewADJLineNo
            END
         END
         
         -- Update child expiry date
         SET @cADJLineNo = ''
         SELECT @cADJLineNo = AdjustmentLineNumber
         FROM AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @c_AdjustmentKey
            AND Lottable10 = @cLottable07
            AND Lottable11 = @cLottable08
            AND Lottable04 IS NULL
         IF @cADJLineNo <> ''
         BEGIN
            UPDATE AdjustmentDetail SET
               Lottable04 = @dExternLottable04, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE AdjustmentKey = @c_AdjustmentKey
               AND AdjustmentLineNumber = @cADJLineNo
            IF @@ERROR <> 0
            BEGIN  
               SET @n_Continue = 3  
               SET @n_Err = 131556  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' ADJLineNo: ' +  CAST( @cADJLineNo AS NVARCHAR(5)) + 'Update AdjustmentDetail fail. (isp_RCM_ADJ_CPV)'      
               GOTO QUIT_SP  
            END
         END
         
         FETCH NEXT FROM @curDTL INTO @cParentSKU, @cADJLineNo, @nQTY_ADJ, @cLottable07, @cLottable08    
      END

      -- Check adjustment allocated
      IF NOT EXISTS( SELECT TOP 1 1
         FROM AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @c_AdjustmentKey
            AND LOT = '') 
      BEGIN
         -- Finalize adjustment
         UPDATE Adjustment SET 
            -- FinalizedFlag = 'Y', 
            UserDefine10 = '',  
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE() 
         WHERE AdjustmentKey = @c_AdjustmentKey
         IF @@ERROR <> 0
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 131557  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update Adjustment Fail. (isp_RCM_ADJ_CPV)'      
            GOTO QUIT_SP  
         END
      END
   END
   ELSE
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err = 131558  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ADJ already finalized or RDT not yet close ADJ (isp_RCM_ADJ_CPV)'     
      GOTO QUIT_SP  
   END

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ADJ_CPV'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END

GO