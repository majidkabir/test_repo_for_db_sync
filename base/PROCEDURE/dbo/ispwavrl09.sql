SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispWAVRL09                                                       */
/* Creation Date: 06-Jun-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22673 - AU OODIE - Send label interface to middleware   */ 
/*                                                                      */
/* Usage:   Storerconfig WaveReleaseToWCS_SP={SPName} to enable release */
/*          Wave to WCS option                                          */
/*                                                                      */
/* Called By: isp_WaveReleaseToWCS_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 06-Jun-2023  NJOW     1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispWAVRL09] 
   @c_WaveKey  NVARCHAR(10),
   @b_Success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue                INT
         , @b_debug                   INT
         , @n_StartTranCnt            INT
         , @c_Orderkey                NVARCHAR(10)
         , @c_PickSlipNo              NVARCHAR(10)
         , @c_LabelNo                 NVARCHAR(20)
         , @c_StorerKey               NVARCHAR(15)
         , @c_Facility                NVARCHAR(5)
         , @c_SKU                     NVARCHAR(20)
         , @n_PackQty                 INT
         , @c_CartonType              NVARCHAR(10)
         , @n_CartonNo                INT
         , @n_TotPackQty              INT      
         , @c_AssignPackLabelToOrdCfg NVARCHAR(30)

   IF @n_err = 1
      SET @b_debug = 1

   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''
   
   IF @n_StartTranCnt = 0
      BEGIN TRAN
  
   ------Validation--------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN          
   	  IF EXISTS(SELECT 1
   	            FROM WAVEDETAIL WD (NOLOCK)
   	            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	            LEFT JOIN PICKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
   	            WHERE WD.Wavekey = @c_Wavekey
   	            AND PH.Pickheaderkey IS NULL)
   	  BEGIN 
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave release failed. Found some orders of the wave are not printed pickslip yet. (ispWAVRL09)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
   	  END          
   	   
   	  IF EXISTS(SELECT 1
   	            FROM WAVEDETAIL WD (NOLOCK)
   	            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	            WHERE WD.Wavekey = @c_Wavekey
   	            AND (O.Status < '2'
   	               OR O.Ecom_Single_flag <> 'S'))
   	  BEGIN 
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave release failed. Found some orders of the wave are not allocated yet. (ispWAVRL09)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
   	  END             	      	 
   END   
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.Storerkey,
   	               @c_Facility = O.Facility
   	  FROM WAVEDETAIL WD (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	  WHERE WD.Wavekey = @c_Wavekey   
 
      IF NOT EXISTS(SELECT 1
                    FROM STORERCONFIG (NOLOCK)
                    WHERE Storerkey = @c_Storerkey
                    AND Configkey = 'AssignPackLabelToOrdCfg')
      BEGIN
         INSERT INTO STORERCONFIG (Storerkey, Facility, Configkey, ConfigDesc, Svalue, Option2, Option3) 
                          VALUES (@c_Storerkey, '', 'AssignPackLabelToOrdCfg', 'Update labelno to pickdetail.caseid', '1', 'CaseID', 'FullLabelNo')                 
      END              
      
      EXECUTE nspGetRight
         @c_facility,
         @c_StorerKey,
         '',
         'AssignPackLabelToOrdCfg', -- Configkey
         @b_success    OUTPUT,
         @c_AssignPackLabelToOrdCfg OUTPUT,
         @n_err        OUTPUT,
         @c_errmsg     OUTPUT      
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT WD.Orderkey
         FROM WAVEDETAIL WD (NOLOCK)
         WHERE WD.Wavekey = @c_Wavekey
      
      OPEN CUR_ORD    
      
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)   
      BEGIN                              
      	 --Create packing
      	 IF @n_continue IN(1,2)
      	 BEGIN
      	    EXEC isp_CreatePickSlip                                                     
                @c_Orderkey = @c_Orderkey
               ,@c_PickslipType = ''                                                 
               ,@c_ConsolidateByLoad  = 'N'                                          
               ,@c_Refkeylookup       = 'N'                                          
               ,@c_LinkPickSlipToPick = 'N'                                          
               ,@c_AutoScanIn         = 'N'                                          
               ,@b_Success            = @b_Success OUTPUT                             
               ,@n_Err                = @n_Err     OUTPUT                             
               ,@c_ErrMsg             = @c_ErrMsg  OUTPUT                             
                                                                                  
            IF @b_Success <> 1                                                           
               SET @n_Continue = 3         	                                            
               
            SELECT @c_PickslipNo = PH.PickHeaderkey
            FROM PICKHEADER PH (NOLOCK)
            WHERE PH.Orderkey = @c_Orderkey   
            
            IF NOT EXISTS(SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickslipNo = @c_Pickslipno)
            BEGIN
               INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                      SELECT TOP 1 O.Route, O.Orderkey, '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo
                      FROM  PICKHEADER PH (NOLOCK)
                      JOIN  Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                      WHERE PH.PickHeaderKey = @c_PickSlipNo
               
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67130
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packheader Table (ispWAVRL09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               END
               
    	         SET @c_LabelNo = ''
    	         SET @n_CartonNo = 1
    	         SET @c_CartonType = 'CTN'
         	     EXEC isp_GenUCCLabelNo_Std
                  @cPickslipNo = @c_Pickslipno,
                  @nCartonNo   = @n_CartonNo,
                  @cLabelNo    = @c_LabelNo  OUTPUT,
                  @b_success   = @b_success  OUTPUT,
                  @n_err       = @n_err      OUTPUT,
                  @c_errmsg    = @c_errmsg   OUTPUT  	             
               
               IF @b_success <> 1
                  SET @n_continue = 3               
 
               DECLARE CUR_PACKSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT OD.Storerkey, OD.Sku, SUM(PD.Qty)
                  FROM ORDERS O (NOLOCK)
                  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                  JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
                  WHERE O.Orderkey = @c_Orderkey
                  GROUP BY OD.Storerkey, OD.Sku
                                                 
               OPEN CUR_PACKSKU
               
               FETCH NEXT FROM CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_PackQty
               
               SET @n_TotPackQty = 0
               WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get sku
               BEGIN            
                  -- CartonNo and LabelLineNo will be inserted by trigger
                  INSERT INTO PACKDETAIL (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno, DropID)
                  VALUES (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_StorerKey, @c_SKU,
                          @n_PackQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '', @c_Orderkey)
                  
                  SET @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67140
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packdetail Table (ispWAVRL09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                  END
                  
                  SELECT @n_TotPackQty = @n_TotPackQty + @n_PackQty
               	
                  FETCH NEXT FROM CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_PackQty           	
               END
               CLOSE CUR_PACKSKU
               DEALLOCATE CUR_PACKSKU
               
   	           INSERT INTO PACKINFO (Pickslipno, CartonNo, CartonType, Cube, Weight, Qty)
   	           VALUES (@c_PickslipNo, @n_CartonNo, @c_CartonType, 0, 0, @n_TotPackQty)
               
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67150
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packinfo Table (ispWAVRL09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               END                             
            END                                                      	  
      	 END

         IF @n_continue IN(1,2)
         BEGIN
         	  UPDATE PACKHEADER WITH (ROWLOCK)
         	  SET Status = '9'
         	  WHERE PickslipNo = @c_Pickslipno

            SET @n_err = @@ERROR
            
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3     
               SELECT @n_err = CONVERT(NVARCHAR(250),@n_err), @n_err = 67160 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PACKHEADER failed. (ispWAVRL09)' 
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            END           	  
         END
         
         IF @n_continue IN(1,2) AND @c_AssignPackLabelToOrdCfg = 1
         BEGIN
     	      EXEC isp_AssignPackLabelToOrderByLoad
      	         @c_Pickslipno = @c_Pickslipno,
                 @b_Success    = @b_Success OUTPUT,
                 @n_err        = @n_err     OUTPUT,
                 @c_errmsg     = @c_errmsg  OUTPUT         	
             
             IF @b_Success <> 1
                SELECT @n_continue = 3    
         END
      	 
      	 --Send middleware interface 
      	 IF @n_continue IN(1,2)
      	 BEGIN
      	    SET @b_Success = 1
            EXEC isp_Carrier_Middleware_Interface    
                  @c_OrderKey    = @c_Orderkey
                 ,@c_Mbolkey     = ''
                 ,@c_FunctionID  = 'ODWAVE'
                 ,@n_CartonNo    = 1
                 ,@n_Step        = 0
                 ,@b_Success     = @b_Success  OUTPUT      
                 ,@n_Err         = @n_Err      OUTPUT      
                 ,@c_ErrMsg      = @c_ErrMsg   OUTPUT      
                 
            IF @b_Success = 0
            BEGIN
               SELECT @n_continue = 3     
               SELECT @n_err = 67170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave release failed. (ispWAVRL09)' 
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            END  
         END            
                     
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey      	
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD               
   END

RETURN_SP:

   IF ISNULL(@c_errmsg,'') = ''
      SET @c_errmsg = 'Interface records generated successfully'

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVRL09'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO