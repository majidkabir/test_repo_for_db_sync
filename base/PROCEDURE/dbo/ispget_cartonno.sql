SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispGet_CartonNo                                    */
/* Creation Date: 2005-03-25                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: NIKE TAIWAN Scan and Pack Module                          */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver.  Purposes                                   */
/* 17-Jul-2013  SHONG  1.1   Change Get Next Carton No using trigger    */
/* 24-Sep-2013  NJOW01 1.2   290121-Configurable generate label no      */
/* 13-MAY-2106  Wan01  1.3   Specify SP parameters                      */ 
/* 08-NOV-2017  CSCHONG1.4   WMS-3389- cater for conso orders (CS01)    */ 
/* 09-NOV-2020  SPChin 1.5   INC1342431 - Bug Fixed                     */
/************************************************************************/

CREATE PROC [dbo].[ispGet_CartonNo]
         @c_PickSlipNo   NVARCHAR(20)  OUTPUT,
         @n_CartonNo     int       OUTPUT,
         @b_Success      int       OUTPUT,
         @n_err          int       OUTPUT,
         @c_errmsg       NVARCHAR(255) OUTPUT
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @n_count int /* next key */
DECLARE @n_ncnt int
DECLARE @n_starttcnt int /* Holds the current transaction count */
DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */
DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */
DECLARE @c_checkorderkey NVARCHAR(255) -- Check ORDERKEY if available
SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''


	--CS01 Start
	SET @c_checkorderkey = ''
	SELECT TOP 1 @c_checkorderkey = ORDERKEY FROM PICKHEADER (NOLOCK) where PICKHEADERKEY = @c_PickSlipNo
	--CS02 End
-- Added By SHONG on 05-May-2005
-- SOS# 35108 
-- NSC Taiwan Scan Pack Module Changes 
DECLARE @cLabelNo NVARCHAR(20)  --NJOW01

BEGIN TRANSACTION 

IF NOT EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK) WHERE PICKHEADERKEY = @c_PickSlipNo)
BEGIN
   SET ROWCOUNT 1
   
   IF @@ROWCOUNT = 0 
   BEGIN
      SELECT @n_continue = 3 
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='Invalid Pick Slip No or Carton Barcode No. (ispGet_CartonNo)' 
   END 
   SET ROWCOUNT 0 
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN 
   IF dbo.fnc_RTrim(@c_PickSlipNo) IS NOT NULL AND dbo.fnc_RTrim(@c_PickSlipNo) <> '' 
   BEGIN
      IF (SELECT ScanOutDate FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) IS NOT NULL
      BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err=61901
         SELECT @c_errmsg='Pick Slip Already Scan Out. (ispGet_CartonNo)' 
      END 
   END
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF dbo.fnc_RTrim(@c_PickSlipNo) IS NOT NULL AND dbo.fnc_RTrim(@c_PickSlipNo) <> '' 
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         SET ROWCOUNT 1 
		 IF (ISNULL(@c_checkorderkey,'')='')  --CS01 Start
		 BEGIN
		 	INSERT INTO PackHeader(PickSlipNo, StorerKey, Route, OrderKey, OrderRefNo, LoadKey, ConsigneeKey, Status)
			SELECT @c_PickSlipNo, MIN(ORDERS.StorerKey), MIN(ORDERS.Route), '', '', MIN(ORDERS.LoadKey), MIN(ORDERS.ConsigneeKey),
			'0'
			FROM  PickHeader (NOLOCK) 
			JOIN  ORDERS (NOLOCK) ON (PICKHEADER.ExternOrderKey = ORDERS.LoadKey)
			WHERE PICKHEADER.PickHeaderKey = @c_PickSlipNo
			GROUP BY
			 ORDERS.StorerKey
			,ORDERS.Route
			,ORDERS.LoadKey
			,ORDERS.ConsigneeKey
		 END 

		 ELSE   --CS01 END
		 BEGIN
			INSERT INTO PackHeader(PickSlipNo, StorerKey, Route, OrderKey, OrderRefNo, LoadKey, ConsigneeKey, Status)
			SELECT PickHeaderKey, ORDERS.StorerKey, ORDERS.Route, ORDERS.OrderKey, '', ORDERS.LoadKey, ORDERS.ConsigneeKey, 
				 '0'
			FROM  PickHeader (NOLOCK) 
			JOIN  ORDERS (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey) 
			WHERE PICKHEADER.PickHeaderKey = @c_PickSlipNo
		 END

         IF NOT EXISTS(SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
             SELECT @n_continue = 3 
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PackHeader Failed. (ispGet_CartonNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM PickingInfo (NOLOCK) Where PickSlipNo = @c_PickSlipNo)
            BEGIN
               INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)
               IF @@ERROR <> 0 
               BEGIN
                   SELECT @n_continue = 3 
                   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickingInfo Failed. (ispGet_CartonNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END 
         END

         SET ROWCOUNT 0 
      END 
   END -- IF NOT dbo.fnc_RTrim(@c_PickSlipNo) 
END -- IF @n_continue = 1 OR @n_continue = 2

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @n_CartonNo IS NULL OR @n_CartonNo = 0 
   BEGIN
      -- Insert Dummy line in PackDetail to Get the next carton number
--      SELECT @n_CartonNo = ISNULL(MAX(CartonNo), 0) + 1 
--      FROM   PACKDETAIL (NOLOCK)
--      WHERE  PickSlipNo = @c_PickSlipNo 
      -- Added By SHONG on 05-May-2005
      -- SOS# 35108 
      -- NSC Taiwan Scan Pack Module Changes 

      --INC1342431 Start
      SET @n_CartonNo = 0
      SELECT TOP 1 @n_CartonNo = PD.CartonNo 
      FROM PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo  = @c_PickSlipNo
      AND PD.SKU = '' 
      AND PD.Storerkey = ''
      ORDER BY PD.CartonNo
      
      IF @n_CartonNo > 0
         GOTO EXIT_SP      
      --INC1342431 End

      /*
        EXECUTE nspg_getkey
         'PackNo' ,
         10,
         @cLabelNo       Output ,
         @b_success      = @b_success output,
         @n_err          = @n_err output,
         @c_errmsg       = @c_errmsg output,
         @b_resultset    = 0,
         @n_batch        = 1
      */
      --NJOW01   
        EXECUTE isp_GenUCCLabelNo_Std
        @cPickslipNo = @c_PickSlipNo,        --(Wan01)
        @cLabelNo    = @cLabelNo   OUTPUT,   --(Wan01) 
        @b_success   = @b_success  OUTPUT,   --(Wan01)
        @n_err       = @n_err      OUTPUT,   --(Wan01)
        @c_errmsg    = @c_errmsg   OUTPUT    --(Wan01)
               

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'nspg_getkey' + dbo.fnc_RTrim(@c_errmsg)
         GOTO EXIT_SP 
      END

      INSERT INTO PackDetail(PickSlipNo, CartonNo, LabelLine, LabelNo, StorerKey, SKU, Qty, RefNo)
      VALUES (@c_PickSlipNo, 0, '00000', @cLabelNo, '', '', 0, '')
      --Insert 0 As Carton No to let system to generate carton from Trigger
      --VALUES (@c_PickSlipNo, @n_CartonNo, '00001', @cLabelNo, '', '', 0, '')
        
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Pack Detail Failed. (ispGet_CartonNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      
      SET @n_CartonNo = 0
      SELECT @n_CartonNo = pd.CartonNo 
      FROM PackDetail pd WITH (NOLOCK)
      WHERE pd.PickSlipNo  = @c_PickSlipNo
      AND pd.LabelNo = @cLabelNo 
      AND pd.SKU='' 
      IF ISNULL(@n_CartonNo,0) = 0 
      BEGIN
          SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Carton Number Failed. (ispGet_CartonNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END      
   END 
END 

EXIT_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0     
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
   BEGIN
       ROLLBACK TRAN
   END
   ELSE BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt 
       BEGIN
           COMMIT TRAN
       END          
   END
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispGet_CartonNo'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE 
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt 
   BEGIN
       COMMIT TRAN
   END
   RETURN
END
-- procedure

GO