SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Stored Procedure: ispUpdatePackSerialNoSP01                                */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: DYSON update PackSerialNo.PickDetailKey                           */
/*             For Retail, PickDetail.DropID have value                       */
/*             For ECOMM, PickDetail.DropID is blank                          */
/*                                                                            */
/* Date         Author  Rev   Purposes                                        */
/* 26-05-2017   Ung     1.0   WMS-1919 Created                                */
/* 13-06-2017   Wan01   1.0   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING         */
/******************************************************************************/
CREATE PROC [dbo].[ispUpdatePackSerialNoSP01]
     @c_Storerkey  NVARCHAR(15)
   , @c_Facility   NVARCHAR(5)
   , @c_PickSlipNo NVARCHAR(10)
   , @c_OrderKey   NVARCHAR(10)
   , @c_LoadKey    NVARCHAR(10)
   , @b_Success    INT           OUTPUT
   , @n_Err        INT           OUTPUT
   , @c_ErrMsg     NVARCHAR(250) OUTPUT
   , @b_debug      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_starttcnt INT
   DECLARE @n_Continue  INT
   
   DECLARE @cResetCaseID      NVARCHAR( 1)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cNewPickDetailKey NVARCHAR( 10)
   DECLARE @nCartonNo         INT
   DECLARE @cLabelNo          NVARCHAR( 20)
   DECLARE @cLabelLine        NVARCHAR( 10)
   DECLARE @cDropID           NVARCHAR( 20)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @nPackSerialNoKey  BIGINT
   DECLARE @nSerialQTY        INT
   DECLARE @nBal              INT
   DECLARE @nPickQTY          INT
   DECLARE @nSplitQTY         INT

   DECLARE @c_TaskBatchNo     NVARCHAR(10)

   DECLARE @curPD CURSOR
   DECLARE @curSNO CURSOR 

   SET @n_starttcnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @c_ErrMsg    = ''

   -- Check PickDetail.CaseID not blank
   IF @c_OrderKey <> ''
   BEGIN
      IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND CaseID <> '')
      BEGIN
         SET @cResetCaseID = 'Y'
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey
            FROM PickDetail WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
               AND CaseID <> ''
            ORDER BY PickDetailKey
      END
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT TOP 1 1 
         FROM LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         WHERE LPD.Loadkey = @c_LoadKey
            AND PD.CaseID <> '')
      BEGIN
         SET @cResetCaseID = 'Y'
         SET @curPD = CURSOR FOR
         SELECT PD.PickDetailKey
         FROM LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         WHERE LPD.Loadkey = @c_LoadKey
            AND PD.CaseID <> ''
         ORDER BY PD.PickDetailKey
      END
   END
   
   -- Reset PickDetail.CaseID
   IF @cResetCaseID = 'Y'
   BEGIN
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail SET 
            CaseID = '',
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 110201
            SELECT @c_errmsg = 'NSQL110201 Reset PickDetail.CaseID fail (PickDetailKey=' + @cPickDetailKey + ') (ispUpdatePackSerialNoSP01)'
            BREAK
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
   END
       
   -- Loop PackSerialNo
   IF (@n_Continue = 1) OR (@n_Continue = 2)
   BEGIN
      --(Wan01) - START
      SET @c_TaskBatchNo = ''
      SELECT @c_TaskBatchNo = ISNULL(RTRIM(TaskBatchNo),'')
      FROM PACKHEADER WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      --(Wan01) - END

      SET @curSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.CartonNo, PD.LabelNo, PD.LabelLine, PD.DropID, PD.SKU, PSNO.PackSerialNoKey, PSNO.QTY
         FROM PackDetail PD WITH (NOLOCK) 
            JOIN PackSerialNo PSNO WITH (NOLOCK) ON (PD.PickSlipNo = PSNO.PickSlipNo AND PD.CartonNo = PSNO.CartonNo AND PD.LabelNo = PSNO.LabelNo AND PD.LabelLine = PSNO.LabelLine)
         WHERE PD.PickSlipNo = @c_PickSlipNo
         ORDER BY PD.CartonNo, PD.LabelNo, PD.LabelLine
      OPEN @curSNO
      FETCH NEXT FROM @curSNO INTO @nCartonNo, @cLabelNo, @cLabelLine, @cDropID, @cSKU, @nPackSerialNoKey, @nSerialQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cPickDetailKey = ''
         SET @nBal = @nSerialQTY
         
         -- Find PickDetail to offset
         WHILE @nBal > 0
         BEGIN
            --(Wan01) - START 
            IF @c_TaskBatchNo <> ''
            BEGIN
               IF @c_OrderKey = ''
                  SELECT TOP 1
                     @cPickDetailKey = PD.PickDetailKey, 
                     @nPickQTY = QTY
                  FROM LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  WHERE LPD.Loadkey = @c_LoadKey
                     AND PD.CaseID = ''
                     AND PD.Sku = @cSKU
                     AND PD.PickDetailKey > @cPickDetailKey
                  ORDER BY PD.PickDetailKey
               ELSE
                  SELECT TOP 1
                     @cPickDetailKey = PickDetailKey, 
                     @nPickQTY = QTY
                  FROM PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @c_OrderKey
                     AND CaseID = ''
                     AND SKU = @cSKU
                  AND PickDetailKey > @cPickDetailKey
                  ORDER BY PickDetailKey
            END
            ELSE
            BEGIN
            --(Wan01) - END
               IF @c_OrderKey = ''
                  SELECT TOP 1
                     @cPickDetailKey = PD.PickDetailKey, 
                     @nPickQTY = QTY
                  FROM LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  WHERE LPD.Loadkey = @c_LoadKey
                     AND PD.Dropid = @cDropid
                     AND PD.CaseID = ''
                     AND PD.Sku = @cSKU
                     AND PD.PickDetailKey > @cPickDetailKey
                  ORDER BY PD.PickDetailKey
               ELSE
                  SELECT TOP 1
                     @cPickDetailKey = PickDetailKey, 
                     @nPickQTY = QTY
                  FROM PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @c_OrderKey
                     AND Dropid = @cDropid
                     AND CaseID = ''
                     AND SKU = @cSKU
                  AND PickDetailKey > @cPickDetailKey
                  ORDER BY PickDetailKey
            END   --(Wan01)

            IF @@ROWCOUNT = 0
               BREAK
      
            -- PickDetail have less
            IF @nPickQTY <= @nBal
            BEGIN
               UPDATE PickDetail WITH (ROWLOCK) SET 
                  CaseID = @cLabelNo,
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
       SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 110202
                  SELECT @c_errmsg = 'NSQL110202 Update PickDetail.CaseID fail (PickDetailKey=' + @cPickDetailKey + ') (ispUpdatePackSerialNoSP01)'
                  BREAK
               END
               
               SELECT @nBal = @nBal - @nPickQTY
            END
            
            -- PickDetail have more, need to split
            -- (For Dyson, PackSerialNo.QTY = 1. Don't have issue where 1 PackSerialNo = 2 PickDetail)
            ELSE
            BEGIN
               SET @nSplitQTY = @nPickQTY - @nBal
               
               -- Get new PickDetailKey
               EXECUTE nspg_GetKey
                  'PickDetailKey',
                  10,
                  @cNewPickDetailKey OUTPUT,
                  @b_success         OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 110203
                  SELECT @c_errmsg = 'NSQL110203 GetKey fail (PickDetailKey) (ispUpdatePackSerialNoSP01)'
                  BREAK
               END
      
               -- Split new PickDetail to carry the balance
               INSERT PickDetail (
                  PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                  Storerkey, Sku, AltSku, UOM, UOMQTY, QTY, QTYMoved, Status,
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )
               SELECT 
                  @cNewPickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                  Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @nSplitQTY ELSE UOMQTY END, @nSplitQTY, QTYMoved, Status,
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                  WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo
               FROM PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 110204
                  SELECT @c_errmsg = 'NSQL110203 Insert PickDetail (ispUpdatePackSerialNoSP01)'
                  BREAK
               END
      
               -- Update original PickDetail with actual
               UPDATE PickDetail WITH (ROWLOCK) SET 
                  CaseID = @cLabelNo,
                  QTY = @nBal,
                  UOMQTY = CASE UOM WHEN '6' THEN @nBal ELSE UOMQTY END, 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 110205
                  SELECT @c_errmsg = 'NSQL110205 Update PickDetail.CaseID fail (PickDetailKey=' + @cPickDetailKey + ') (ispUpdatePackSerialNoSP01)'
                  BREAK
               END
      
               SET @nBal = 0
            END
            
            -- Stamp PackSerialNo.PickDetailKey
            UPDATE PackSerialNo SET
               PickDetailKey = @cPickDetailKey, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE PackSerialNoKey = @nPackSerialNoKey
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 110206
               SELECT @c_errmsg = 'NSQL110206 Update PackSerialNo.PickDetailKey fail (PackSerialNoKey=' + @nPackSerialNoKey + ') (ispUpdatePackSerialNoSP01)'
               BREAK
            END
         END
   
         -- Check offset error
         IF @nBal <> 0
         BEGIN
            SET @n_err = 63333
            SELECT @n_err = 110207
            SELECT @c_errmsg = 'NSQL110207 Offset PickDetail fail (@nBal=' + CAST( @nBal AS NVARCHAR(5)) + ') (ispUpdatePackSerialNoSP01)'
            BREAK
         END
         
         FETCH NEXT FROM @curSNO INTO @nCartonNo, @cLabelNo, @cLabelLine, @cDropID, @cSKU, @nPackSerialNoKey, @nSerialQTY
      END
   END
   
   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
         BEGIN
            ROLLBACK TRAN
         END

         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUpdatePackSerialNoSP01'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      RETURN
   END

END -- Procedure

GO