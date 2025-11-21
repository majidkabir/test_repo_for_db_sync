SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* SP: ispRF_PickNPackConfirm                                             */
/* Creation Date:                                                         */
/* Copyright: IDS                                                         */
/* Written by: Shong                                                      */
/*                                                                        */
/* Purpose: Timberland HK PDADynamic Pick Confirmation                    */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Called By: Power Builder Allocation from Load Plan                     */
/*                                                                        */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* 06-Jan-2009  Shong    1.1  SOS127605 TBL PDA pickdetail and packdetail */ 
/*                            mismatch.                                   */
/* 10-Jul-2012  Shong    1.2  Over Pack Issues Checking                   */
/**************************************************************************/
CREATE PROCEDURE [dbo].[ispRF_PickNPackConfirm] 
   @c_PickDetailKey  NVARCHAR(10)  OUTPUT,
   @c_PickSlipNo     NVARCHAR(10),
   @n_CartonNo       int,
   @c_LabelNo        NVARCHAR(20),
   @c_StorerKey      NVARCHAR(18),
   @c_SKU            NVARCHAR(20),
   @n_SysPickQty     int,
   @n_UserPickQty    int,
   @c_ShortPick      NVARCHAR(1),
   @c_FinalizePack   NVARCHAR(1),
   @c_Button         NVARCHAR(1),
   @b_Success        int       OUTPUT,
   @n_Err            int       OUTPUT,
   @c_ErrMsg         NVARCHAR(250) OUTPUT   
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
DECLARE @n_continue        int,
      @n_StartTCnt         int,
      @n_Cnt               int,
      @c_LabelLine         NVARCHAR(5),
      @c_OldPickDetailKey  NVARCHAR(10),
      @n_QtyPacked         INT,
      @n_QtyAllocated      INT 

SELECT @n_continue = 1,
       @n_StartTCnt = @@TRANCOUNT         

BEGIN TRANSACTION

--IF @n_continue = 1 or @n_continue=2 
--BEGIN 
--   INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) VALUES
--      ('ispRF_PickNPackConfirm', 
--        getdate(), 
--        getdate(), 
--        suser_sname(),                  -- Step 1
--        LEFT(@c_PickDetailKey,12),      -- Step 2
--        LEFT(@c_PickSlipNo,12),         -- Step 3
--        CAST(@n_CartonNo as NVARCHAR(12)),  -- Step 4
--        '',                             -- Step 5
--        @c_SKU,           -- Col 1
--        @c_LabelNo,       -- Col 2
--        @c_ShortPick,     -- Col 3
--        CAST(@n_SysPickQty  as NVARCHAR(20)), 
--        CAST(@n_UserPickQty as NVARCHAR(20)) 
--      )
--END 


IF @n_continue = 1 OR @n_continue = 2
BEGIN
	IF EXISTS(SELECT 1 FROM PICKDETAIL p WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey AND Status < '5')
	BEGIN
      -- update pickdetail
      UPDATE PICKDETAIL WITH (ROWLOCK) 
      SET Status = '5',
          qty = @n_UserPickQty
      WHERE PickDetailKey = @c_PickDetailKey
        AND Status < '5'
      
      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
      IF @n_Err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Pickdetail Update Failed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_ErrMsg)) + ' ) '
      END		
	END 
	ELSE
	BEGIN
		SET @n_QtyAllocated = 0 
		SET @n_QtyPacked = 0 
		
		SELECT @n_QtyAllocated = ISNULL(p.Qty,0) 
		FROM PICKDETAIL p WITH (NOLOCK) 
		WHERE p.PickDetailKey = @c_PickDetailKey
		
		SELECT @n_QtyPacked = ISNULL(SUM(Qty),0)
		FROM PackDetail pd WITH (NOLOCK)
		WHERE pd.PickSlipNo = @c_PickSlipNo  
		AND Refno = @c_PickDetailKey 
		AND pd.StorerKey = @c_StorerKey 
		AND pd.SKU = @c_SKU
		
		IF @n_QtyPacked + @n_UserPickQty > @n_QtyAllocated 
		BEGIN
         SELECT @n_continue = 3 
         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 63530   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Over Packed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_ErrMsg)) + ' ) '
      END
	END
END


IF (@n_continue = 1 OR @n_continue = 2) AND @n_UserPickQty > 0
BEGIN -- insert packdetail
   SET @c_LabelLine = ''

   SELECT @c_LabelLine = MAX(labelline)
   FROM  PACKDETAIL (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
      AND CartonNo = @n_CartonNo
      AND LabelNo = @c_LabelNo

   IF ISNULL(RTRIM(@c_LabelLine), '') = '' 
      SELECT @c_LabelLine = '00001'
   ELSE
      SELECT @c_LabelLine = RIGHT('00000' + RTrim(CONVERT(CHAR(5), CONVERT(INT, @c_LabelLine) + 1)), 5)

   -- Commended by SHONG on 2nd Feb 2009
   -- AND CartonNo = @n_CartonNo AND LabelNo = @c_LabelNo 
   IF NOT EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Refno = @c_PickDetailKey AND CartonNo = @n_CartonNo AND LabelNo = @c_LabelNo)
   BEGIN 
      INSERT INTO PACKDETAIL (PickSlipNo, CartonNo, LabelNo , LabelLine, Storerkey, Sku, Qty, RefNo)
         VALUES (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_SKU, @n_UserPickQty, @c_PickDetailKey)
   
      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
      IF @n_Err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 63530   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Packdetail Insert Failed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_ErrMsg)) + ' ) '
      END
   END 
END -- insert packdetail

-- Start SOS30023 : Changed by June 03.Dec.2004 - bug fix no Task generated by pending pickdetail records
-- Move this script to after Insert Packdetail
IF (@n_continue = 1 OR @n_continue = 2) AND @c_ShortPick = 'N' AND @c_Button = '2' -- split case scenario
BEGIN -- insert new pickdetail
   SELECT @b_Success = 0, @c_OldPickDetailKey = @c_PickDetailKey
   EXECUTE nspg_getkey
      'PickDetailKey'   
      , 10
      , @c_PickDetailKey OUTPUT
      , @b_Success OUTPUT
      , @n_Err OUTPUT
      , @c_ErrMsg OUTPUT
         
   IF @b_Success = 1
   BEGIN
      INSERT INTO PICKDETAIL( PickDetailKey, Caseid, PickHeaderKey, Orderkey, OrderlineNumber, Storerkey, Sku,
                              UOM, UOMQty, Packkey, Lot, Loc, ID, Qty, CartonType, PickSlipNo, WaveKey)
         SELECT @c_PickDetailKey, Caseid, PickHeaderKey, Orderkey, OrderlineNumber, Storerkey, Sku,
               UOM, UOMQty, Packkey, Lot, Loc, ID, @n_SysPickQty - @n_UserPickQty, CartonType, PickSlipNo, WaveKey
         FROM PICKDETAIL (NOLOCK)
         WHERE PickDetailKey = @c_OldPickDetailKey

      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
      IF @n_Err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Pickdetail Insert Failed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_ErrMsg)) + ' ) '
      END
   END
   ELSE
   BEGIN 
      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
      IF @n_Err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 63529   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Pickdetail Key Generation Failed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_ErrMsg)) + ' ) '
      END
   END
END -- insert new pickdetail
-- End SOS30023 

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @c_FinalizePack = 'Y'
      UPDATE PACKHEADER
      SET Status = '9'
      WHERE pickslipno = @c_PickSlipNo
         and Status < '9'
   ELSE IF @c_FinalizePack = 'N' 
      UPDATE PICKINGINFO
      SET scanoutdate = getdate()
      WHERE pickslipno = @c_PickSlipNo
   
   SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
   IF @n_Err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Finalize Pack Failed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_ErrMsg)) + ' ) '
   END
END

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_Success = 0
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
   EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispRF_PickNPackConfirm'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   SELECT @b_Success = 1
   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO