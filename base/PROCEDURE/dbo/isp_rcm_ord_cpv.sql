SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************************************/
/* Store procedure: isp_RCM_ORD_CPV                                                            */
/* Copyright      : LFLogistics                                                                */
/*                                                                                             */
/* Date       Rev  Author    Purposes                                                          */
/* 12-06-2018 1.0  Ung       WMS-5368 Created                                                  */
/* 07-03-2019 1.1  ChewKP    Changes                                                           */
/* 11-03-2019 1.2  ChewKP    Fixes                                                             */
/* 03-03-2022 1.3  CalvinK   JSM-54986 Fixed Rollback Tran bug when inv is not enough (CLVN01) */
/* 02-10-2023 1.4  Ung       WMS-23702 RDT compatible message                                  */
/***********************************************************************************************/

CREATE   PROC [dbo].[isp_RCM_ORD_CPV] (
   @c_OrderKey NVARCHAR(10),
   @b_success INT           OUTPUT,
   @n_err    INT           OUTPUT,
   @c_errmsg NVARCHAR(225) OUTPUT,
   @c_code    NVARCHAR(30) = ''
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess          INT = 0
   DECLARE @nErrNo            INT = 0
   DECLARE @cErrMsg           NVARCHAR (255) = ''
   DECLARE @BeforePickDet     INT = 0           --(CLVN01)

   DECLARE @nTranCount        INT
   DECLARE @nRowRef           INT
   DECLARE @cStorerKey        NVARCHAR(15)
   DECLARE @cStatus           NVARCHAR(10)
   DECLARE @cSKU              NVARCHAR(20)
   DECLARE @cBarcode          NVARCHAR(50)
   DECLARE @cLottable07       NVARCHAR(30)
   DECLARE @cLottable08       NVARCHAR(30)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cLOC              NVARCHAR(10)
   DECLARE @cPackKey          NVARCHAR(10)
   DECLARE @cID               NVARCHAR(18)
   DECLARE @cUserDefine10     NVARCHAR(20)
   DECLARE @cOrderLineNumber  NVARCHAR(5)
   DECLARE @cPickDetailKey    NVARCHAR(10)
   DECLARE @cNewPickDetailKey NVARCHAR(10)
   DECLARE @nQTY              INT
   DECLARE @nQTY_Log          INT
   DECLARE @nQTY_ORD          INT
   DECLARE @nQTY_LLI          INT
   DECLARE @nPickSerialNoKey  BIGINT
   DECLARE @curLog CURSOR
   DECLARE @curPD  CURSOR

   DECLARE @n_continue int,
           @n_starttcnt int

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0

   SELECT
      @cStorerKey = StorerKey,
      @cStatus = Status,
      @cUserDefine10 = UserDefine10
   FROM Orders WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey

   BEGIN TRY
      -- Order ready for alloc
      IF @cStatus < '2' AND
         @cUserDefine10 = 'PENDALLOC'
      BEGIN
         -- Loop log
         SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef, StorerKey, SKU, QTY, Barcode, Lottable07, Lottable08
            FROM rdt.rdtCPVOrderLog WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
            ORDER BY RowRef
         OPEN @curLog
         FETCH NEXT FROM @curLog INTO @nRowRef, @cStorerKey, @cSKU, @nQTY_Log, @cBarcode, @cLottable07, @cLottable08
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @cErrMsg = ''

            WHILE @nQTY_Log > 0
            BEGIN
               IF @cErrMsg = ''
               BEGIN
                  -- Get Order line to fullfil
                  SET @nQTY_ORD = 0
                  SELECT TOP 1
                     @cOrderLineNumber = OrderLineNumber,
                     @cPackKey = PackKey,
                     @nQTY_ORD = OpenQTY - QTYAllocated - QTYPicked
                  FROM OrderDetail WITH (NOLOCK)
                  WHERE OrderKey = @c_OrderKey
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND OpenQTY - QTYAllocated - QTYPicked > 0
                  ORDER BY OrderLineNumber

                  IF @nQTY_ORD = 0
                  BEGIN
                     SET @cErrMsg = 'No suitable order line'
                 SET @BeforePickDet = 1               --(CLVN01)
                     SET @nQTY_Log = 0
                  END
               END

               IF @cErrMsg = ''
               BEGIN
                  -- Get available stock
                  SET @nQTY_LLI = 0
                  SELECT TOP 1
                     @cLOT = LLI.LOT,
                     @cLOC = LLI.LOC,
                     @cID  = LLI.ID,
                     @nQTY_LLI = ISNULL( SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QTYReplen > 0 THEN LLI.QTYReplen ELSE 0 END)), 0)
                  FROM LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                     JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LLI.StorerKey = @cStorerKey
                     AND LLI.SKU = @cSKU
                     AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QTYReplen > 0 THEN LLI.QTYReplen ELSE 0 END) > 0
                     AND LA.Lottable07 = @cLottable07
                     AND LA.Lottable08 = @cLottable08
                     AND LOC.LocationFlag <> 'HOLD'
                  GROUP BY LLI.LOT, LLI.LOC, LLI.ID

                  IF @nQTY_LLI = 0
                  BEGIN
                     SET @cErrMsg = 'No avail stock. SKU: '  + @cSKU + ' Lottable07: ' + @cLottable07 + ' Lottable08: ' + @cLottable08
                 SET @BeforePickDet = 1            --(CLVN01)
                     SET @nQTY_Log = 0
                  END
               END

            IF @cErrMsg = ''
            BEGIN
               SET @BeforePickDet = 0
            END

               IF @cErrMsg = ''
               BEGIN
                  -- Get PickDetail info
                  SET @cPickDetailKey = ''
                  SELECT @cPickDetailKey = PickDetailKey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @c_OrderKey
                     AND OrderLineNumber = @cOrderLineNumber
                     AND LOT = @cLOT
                     AND LOC = @cLOC
                     AND ID = @cID
                     AND Notes = @cBarcode

                  -- Calc QTY for PickDetail (smallest of the 3 QTY)
                  SET @nQTY = @nQTY_Log
                  IF @nQTY > @nQTY_ORD
                     SET @nQTY = @nQTY_ORD
                  IF @nQTY > @nQTY_LLI
                     SET @nQTY = @nQTY_LLI

                  -- Handling transaction
                  SET @nTranCount = @@TRANCOUNT
                  BEGIN TRAN  -- Begin our own transaction
                  SAVE TRAN rdt_Alloc -- For rollback or commit only our own transaction

                  SET @cErrMsg = ''

                  IF @cPickDetailKey <> ''
                  BEGIN
                     -- Top up PickDetail
                     UPDATE PickDetail SET
                        QTY = QTY + @nQTY,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                        SET @cErrMsg = 'UPDATE PickDetail Fail'
                  END
                  ELSE
                  BEGIN
                     -- Get new PickDetailkey
                     SET @cNewPickDetailKey = ''
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     IF @bSuccess <> 1
                        SET @cErrMsg = 'nspg_GetKey Fail'

                     IF @cErrMsg = ''
                     BEGIN
                        INSERT INTO PickDetail
                           (PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, UOM, UOMQTY, QTY, Status, LOC, ID, PackKey, Notes)
                        VALUES
                           (@cNewPickDetailKey, '', @c_OrderKey, @cOrderLineNumber, @cLOT, @cStorerKey, @cSKU, '6', 1, @nQTY, '0', @cLOC, @cID, @cPackKey, @cBarcode)
                        IF @@ERROR <> 0
                           SET @cErrMsg = 'INSERT PickDetail Fail'
                     END
                  END
               END

               -- Delete Log
               IF @cErrMsg = ''
               BEGIN
                  SET @nQTY_Log = @nQTY_Log - @nQTY
                  IF @nQTY_Log = 0
                     DELETE rdt.rdtCPVOrderLog WHERE RowRef = @nRowRef
                  ELSE
                     UPDATE rdt.rdtCPVOrderLog SET
                        QTY = QTY - @nQTY
                     WHERE RowRef = @nRowRef

               COMMIT TRAN rdt_Alloc
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
               END
               ELSE
               BEGIN
            --(CLVN01) START--
               IF @BeforePickDet = 1
               BEGIN
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN

                 -- Log error
                 UPDATE rdt.rdtCPVOrderLog SET
                     Remark = @cErrMsg
                     WHERE RowRef = @nRowRef

                     SET @nQTY_Log = 0
               END
               ELSE
               BEGIN
                     ROLLBACK TRAN rdt_Alloc
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN

                     -- Log error
                     UPDATE rdt.rdtCPVOrderLog SET
                     Remark = @cErrMsg
                     WHERE RowRef = @nRowRef


                     SET @nQTY_Log = 0
               END
               --(CLVN01) END--
               END
            END
            FETCH NEXT FROM @curLog INTO @nRowRef, @cStorerKey, @cSKU, @nQTY_Log, @cBarcode, @cLottable07, @cLottable08
         END

         -- Fully alloc
         IF NOT EXISTS( SELECT TOP 1 1
            FROM OrderDetail WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
               AND OpenQTY > 0
               AND OpenQTY <> QTYAllocated)
         BEGIN

            IF NOT EXISTS ( SELECT TOP 1 1
                           FROM OrderDetail WITH (NOLOCK)
                           WHERE OrderKey = @c_OrderKey
                              AND OriginalQty <> QTYAllocated)
            BEGIN
               -- Pick confirm
               SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT PickDetailKey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @c_OrderKey
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE PickDetail SET
                     Status = '5',
                     EditDate = GETDATE(),
                     EditWho = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                     SET @cErrMsg = 'UPDATE PickDetail Fail'
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
               END

               -- Reset flag
               UPDATE Orders SET
                  UserDefine10 = '',
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE OrderKey = @c_OrderKey
            END
         END
         ELSE
         BEGIN
             -- Reset flag
            UPDATE Orders SET
               UserDefine10 = 'PARTIALALL',
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE OrderKey = @c_OrderKey
         END
      END
      ELSE
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 206901
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Order already allocated or RDT not yet close order (isp_RCM_ORD_CPV)'
         GOTO QUIT_SP
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_Err = 206902
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': error allocate (isp_RCM_ORD_CPV)'
      GOTO QUIT_SP
   END CATCH

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ORD_CPV'
      RAISERROR (@c_errmsg, 10, 1) WITH SETERROR    -- SQL2012
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