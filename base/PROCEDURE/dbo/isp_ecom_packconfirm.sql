SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Ecom_PackConfirm                                        */
/* Creation Date: 26-APR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By:  n_cst_packheader_ecom                                    */
/*          :  ue_packconfirm                                           */
/* PVCS Version: 1.8                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-SEP-2016 Wan01    1.1   Performance Tune                          */
/* 25-OCT-2016 Wan02    1.2   Check Qty Packed against Orders alloc qty */ 
/* 06-JUN-2017 Wan03    1.3   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/* 23-APR-2019 CSCHONG  1.4   WMS-7781 - IKEA-Ecom-Packing (CS01)       */
/* 26-JUN-2019 Wan04    1.5   Order Status Check B4 PackConfirm         */
/* 06-AUG-2020 Wan05    1.6   WMS-14315 - [CN] NIKE_O2_Ecom Packing_CR  */ 
/* 13-FEB-2020 Wan06    1.7   WMS-12083 - [MY] SKECHERS - Exceed        */
/*                            PackIsCompulsory config with ECOM Packing.*/  
/* 2021-03-11  Wan07    1.8   WMS-16026 - PB-Standardize TrackingNo     */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_PackConfirm] 
            @c_PickSlipNo  NVARCHAR(10)      OUTPUT   -- 2019-05-23 Performance Tune to return PickSlipNo to PB to retrieve packheader by pickslipno(refresh)                  
         ,  @b_Success     INT = 0           OUTPUT 
         ,  @n_err         INT = 0           OUTPUT 
         ,  @c_errmsg      NVARCHAR(255) = ''OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         
         , @c_TmpPickSlipNo   NVARCHAR(10) 
         , @c_PDPickSlipNo    NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(10) 
         , @c_Orderkey        NVARCHAR(10) 

         , @n_CartonNo        INT
         , @c_LabelNo         NVARCHAR(20)
         , @c_TrackingNo      NVARCHAR(40)   --(Wan07)

         , @c_TrackingNo_ORD  NVARCHAR(40)   --(Wan07)
         , @c_UserDefine04    NVARCHAR(20)
         , @c_PackLabelToOrd  NVARCHAR(10)

         , @c_TaskBatchNo     NVARCHAR(10)   --(Wan01)
         , @n_RowRef          BIGINT         --(Wan01)

         , @n_PackSerialNoKey BIGINT         --(Wan03)
         , @c_LabelLine       NVARCHAR(5)    --(Wan03)
         , @c_UpdateEstttlctn NVARCHAR(30)   --(CS01)
         , @n_maxctn          INT
         
         , @n_NonePackSO      INT         = 0--(Wan04)   
         , @c_PTD_Status      NVARCHAR(10)=''--(Wan04)  
         , @c_ORDStatus       NVARCHAR(10)=''--(Wan04)
         , @c_SOStatus        NVARCHAR(10)=''--(Wan04)  
         
         , @n_PackQRFKey      BIGINT      =0 --(Wan05)    
         , @cur_PQRF          CURSOR         --(Wan05)         
             

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_TmpPickSlipNo= ''
   SET @c_PDPickSlipNo = @c_PickSlipNo
   SET @c_LabelNo  = ''

   SET @c_Orderkey = ''
   SET @c_TaskBatchNo = ''                               --(Wan01)
   SELECT @c_Orderkey = Orderkey
         ,@c_Storerkey= Storerkey
         ,@c_TaskBatchNo = ISNULL(RTRIM(TaskBatchNo),'') --(Wan01)
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   --(Wan02) -START
   IF EXISTS ( SELECT 1
               FROM ORDERDETAIL OD WITH (NOLOCK)
               LEFT JOIN (SELECT Orderkey = @c_Orderkey , Storerkey, Sku, Qty = ISNULL(SUM(Qty),0)
                           FROM PACKDETAIL WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                           GROUP BY Storerkey, Sku
                           ) AS PACK   ON (PACK.Orderkey = OD.Orderkey)
                                       AND(PACK.Storerkey= OD.Storerkey)
                                       AND(PACK.Sku= OD.Sku)
               WHERE OD.Orderkey = @c_Orderkey
               GROUP BY OD.Orderkey, OD.Storerkey, OD.Sku, PACK.Qty
               HAVING ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0) <> ISNULL(PACK.Qty,0)
            )
   --(Wan02) -END
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60005  
      SET @c_errmsg='There is Sku qtyallocated <> qtypacked. (isp_Ecom_PackConfirm)' 
      GOTO QUIT
   END
   --Validation Check QtyAllocated = QtyPacked Before Pack Confirm - (END)
   
   --(Wan04) - Validate Order Status - START
   SET @n_NonePackSO = 0 
   SET @c_ORDStatus  = ''
   SET @c_SOStatus   = ''
   SELECT @c_ORDStatus = OH.[Status]
         ,@c_SOStatus  = OH.[SOStatus] 
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey

   IF @c_ORDStatus >= '5' OR @c_SOStatus IN ('CANC','HOLD')
   BEGIN
      SET @c_PTD_Status = '9'
      IF @c_SOStatus IN ('CANC','HOLD') 
      BEGIN
         SET @c_PTD_Status = 'X'
      END
      SET @n_NonePackSO = 1
   END

   IF @n_NonePackSO = 0 
   BEGIN
      SELECT TOP 1 @n_NonePackSO = CASE WHEN CL.Storerkey = @c_Storerkey THEN 1 
                                        WHEN CL.Storerkey = '' THEN 1
                                        ELSE 0 END 
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'NONEPACKSO'
      AND   CL.Code     = @c_SOStatus
      ORDER BY CL.Storerkey DESC
             , 1
   END

   IF @n_NonePackSO > 0
   BEGIN
      IF @c_PTD_Status = ''
      BEGIN
         SET @c_PTD_Status = 'X' 
      END

      SET @n_Continue = 3
      SET @n_err = 60006
      SET @c_ErrMsg= 'NSQL'+CONVERT(char(5),@n_err)+': Not allow to pack Confirm'
                   + '. Order Status: ' + @c_ORDStatus + ', Extern Order Status: ' + @c_SOStatus 
                   + '. (isp_Ecom_PackConfirm)'  
      GOTO QUIT    
   END
   --(Wan04) - Validate Order Status - END
           
   --CS01 START
   SET @c_UpdateEstttlctn = '0'
   SET @n_maxctn = 1

   SELECT @c_UpdateEstttlctn = SC.Svalue
   FROM StorerConfig SC WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND configkey='PackUpdateEstTotalCtn'
   --CS01 END
                
   IF @@TRANCOUNT = 0 
      BEGIN TRAN

   -- Create Permanent PickSlipNo
   IF LEFT(@c_PickSlipNo,1) = 'T'
   BEGIN
      SET @c_TmpPickSlipNo = @c_PickSlipNo
      SET @c_PickSlipNo    = ''

      IF @c_Orderkey <> ''
      BEGIN
         SELECT @c_PickSlipNo = PickHeaderKey
         FROM PICKHEADER WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
      END

      IF @c_PickSlipNo = ''
      BEGIN
         /* (Wan01) - START
         EXECUTE nspg_GetKey 
                 @KeyName     = 'PICKSLIP'
               , @fieldlength = 9
               , @keystring   = @c_PickSlipNo  OUTPUT
               , @b_success   = @b_success     OUTPUT
               , @n_err       = @n_err         OUTPUT
               , @c_errmsg    = @c_errmsg      OUTPUT
               , @b_resultset = 0
               , @n_batch     = 0
   
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 60000                                                                                               
            SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
            GOTO QUIT        
         END
         SET @c_PickSlipNo = 'P' + @c_PickSlipNo
         (Wan01) - END*/

         SET @c_PickSlipNo = 'P' +  RIGHT(@c_TmpPickSlipNo,9)        --(Wan01)
         
         -- Zone = 3 - discrete (orderkey, externorderkey), 7 - Consolidate (externorderkey), LP - Loadplan (Loadkey)
         INSERT INTO PICKHEADER 
            (  PickHeaderKey
            ,  Orderkey
            ,  Storerkey
            ,  ExternOrderkey
            ,  Consigneekey
            ,  Priority
            ,  Type
            ,  Zone
            ,  Status
            ,  PickType
            ,  EffectiveDate
            )
         SELECT @c_PickSlipNo
            ,  Orderkey
            ,  Storerkey
            ,  Loadkey
            ,  Consigneekey
            ,  '5'
            ,  '5'
            ,  '3'
            ,  '0'
            ,  '0'
            ,  GETDATE()
         FROM ORDERS WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60010  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PICKHEADER Table. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END

         INSERT INTO PICKINGINFO 
            (  PickSlipNo
            ,  ScanInDate
            ,  ScanOutDate
            ,  PickerID
            ,  TrafficCop
            )
         VALUES 
            (  @c_PickSlipNo
            ,  GETDATE()
            ,  NULL
            ,  SUSER_NAME()
            ,'U'
            )

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60020  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PICKINGINFO Table. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
      END

      INSERT INTO PACKHEADER 
         (  PickSlipNo
         ,  Storerkey
         ,  Orderkey
         ,  Route
         ,  OrderRefNo
         ,  LoadKey
         ,  ConsigneeKey
         ,  Status
         ,  CtnTyp1 
         ,  CtnTyp2 
         ,  CtnTyp3 
         ,  CtnTyp4 
         ,  CtnTyp5 
         ,  CtnCnt1 
         ,  CtnCnt2 
         ,  CtnCnt3 
         ,  CtnCnt4 
         ,  CtnCnt5 
         ,  TotCtnWeight
         ,  TotCtnCube
         ,  CartonGroup
         ,  ManifestPrinted
         ,  ConsoOrderKey
         ,  AddWho
         ,  TaskBatchNo
         ,  ComputerName
         )
      SELECT 
            @c_PickSlipNo
         ,  Storerkey
         ,  Orderkey
         ,  Route
         ,  OrderRefNo
         ,  LoadKey
         ,  ConsigneeKey
         ,  '0'
         ,  CtnTyp1 
         ,  CtnTyp2 
         ,  CtnTyp3 
         ,  CtnTyp4 
         ,  CtnTyp5 
         ,  CtnCnt1 
         ,  CtnCnt2 
         ,  CtnCnt3 
         ,  CtnCnt4 
         ,  CtnCnt5 
         ,  TotCtnWeight
         ,  TotCtnCube
         ,  CartonGroup
         ,  ManifestPrinted
         ,  ConsoOrderKey
         ,  AddWho
         ,  TaskBatchNo
         ,  ComputerName
      FROM PACKHEADER WITH (NOLOCK)
      WHERE PickSlipNo = @c_TmpPickSlipNo

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60030  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PACKHEADER Table. (isp_Ecom_PackConfirm)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END

      IF EXISTS ( SELECT 1
                  FROM PACKINFO WITH (NOLOCK)
                  WHERE PickSlipNo = @c_TmpPickSlipNo )
      BEGIN
         UPDATE PACKINFO WITH (ROWLOCK)
         SET PickSlipNo = @c_PickSlipNo
            ,EditWho    = SUSER_NAME()
            ,EditDate   = GETDATE()
            ,Trafficcop = NULL
         WHERE PickSlipNo = @c_TmpPickSlipNo

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60040  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKINFO Table. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
      END 
   END
   
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;

   IF @@TRANCOUNT = 0 
      BEGIN TRAN;
      
   --Update LabelNo
   DECLARE CUR_PACKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT CartonNo 
         ,LabelNo 
   FROM   PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PDPickSlipNo
   ORDER BY CartonNo
   
   OPEN CUR_PACKD
   
   FETCH NEXT FROM CUR_PACKD INTO @n_CartonNo
                                 ,@c_LabelNo 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF RTRIM(@c_LabelNo) = '' OR @c_LabelNo IS NULL
      BEGIN
         EXEC isp_GenUCCLabelNo_Std  
               @cPickslipNo   = @c_PickSlipNo
            ,  @nCartonNo     = @n_CartonNo
            ,  @cLabelNo      = @c_LabelNo   OUTPUT
            ,  @b_success     = @b_success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg    OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60050 
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
      END

      DECLARE CUR_PACKL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LabelLine 
      FROM   PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @c_PDPickSlipNo
      AND   CartonNo = @n_CartonNo
   
      OPEN CUR_PACKL
   
      FETCH NEXT FROM CUR_PACKL INTO @c_LabelLine
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PACKDETAIL WITH (ROWLOCK)
         SET PickSlipNo = @c_PickSlipNo
            ,LabelNo    = @c_LabelNo
            ,EditWho    = SUSER_NAME()
            ,EditDate   = GETDATE()
            --,ArchiveCop = NULL
         WHERE PickSlipNo = @c_PDPickSlipNo
         AND   CartonNo   = @n_CartonNo
         AND   LabelLine  = @c_LabelLine

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60050 
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKDETAIL Table. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
         FETCH NEXT FROM CUR_PACKL INTO @c_LabelLine
      END
      CLOSE CUR_PACKL
      DEALLOCATE CUR_PACKL

      DECLARE CUR_PACKSN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PackSerialNoKey 
      FROM   PACKSERIALNO WITH (NOLOCK)
      WHERE PickSlipNo = @c_PDPickSlipNo
      AND   CartonNo   = @n_CartonNo
   
      OPEN CUR_PACKSN
   
      FETCH NEXT FROM CUR_PACKSN INTO @n_PackSerialNoKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PACKSERIALNO WITH (ROWLOCK)
         SET PickSlipNo = @c_PickSlipNo
            ,LabelNo    = @c_LabelNo
            ,EditWho    = SUSER_NAME()
            ,EditDate   = GETDATE()
            ,ArchiveCop = NULL
         WHERE PackSerialNoKey = @n_PackSerialNoKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60055 
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKSERIALNO Table. (isp_Ecom_PackConfirm)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
         FETCH NEXT FROM CUR_PACKSN INTO @n_PackSerialNoKey
      END
      CLOSE CUR_PACKSN
      DEALLOCATE CUR_PACKSN

     SET @n_maxctn = @n_CartonNo                --CS01
      -- (Wan03) - END
      FETCH NEXT FROM CUR_PACKD INTO @n_CartonNo
                                    ,@c_LabelNo 
   END
   CLOSE CUR_PACKD
   DEALLOCATE CUR_PACKD 
   
   --(Wan05) - START    
   IF @c_PDPickSlipNo <> @c_PickSlipNo    
   BEGIN    
      SET @cur_PQRF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PQRF.PackQRFKey    
      FROM PACKQRF PQRF WITH (NOLOCK)    
      WHERE PQRF.PickSlipNo = @c_PDPickSlipNo    
      ORDER BY PQRF.PackQRFKey    
    
      OPEN @cur_PQRF      
              
      FETCH NEXT FROM @cur_PQRF INTO @n_PackQRFKey    
    
      WHILE @@FETCH_STATUS <> -1     
      BEGIN    
         UPDATE PACKQRF WITH (ROWLOCK)    
         SET PickSlipNo = @c_PickSlipNo    
            ,EditWho    = SUSER_SNAME()    
            ,EditDate   = GETDATE()    
            ,Trafficcop = NULL    
         WHERE PackQRFKey = @n_PackQRFKey    
    
         SET @n_err = @@ERROR          
             
         IF @n_err <> 0          
         BEGIN          
            SET @n_continue = 3          
            SET @c_errmsg = CONVERT(char(250),@n_err)    
            SET @n_err = 60056    
            SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table PACKQRF. (isp_Ecom_PackConfirm)'     
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '          
            BREAK    
         END      
         FETCH NEXT FROM @cur_PQRF INTO @n_PackQRFKey    
      END    
      CLOSE @cur_PQRF    
      DEALLOCATE @cur_PQRF    
   END    
   --(Wan05) - END    


   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;   

   IF @@TRANCOUNT = 0 
      BEGIN TRAN;
      
   SET @c_TrackingNo = ''                                                                                                                                --(Wan07)
   SELECT TOP 1 @c_TrackingNo = CASE WHEN ISNULL(TrackingNo,'') <> '' THEN RTRIM(TrackingNo) ELSE ISNULL(RTRIM(RefNo),'') END                            --(Wan07)
   FROM PACKINFO WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   ORDER BY CartonNo
      
   SELECT @c_TrackingNo_ORD = CASE WHEN ISNULL(RTRIM(TrackingNo),'') <> '' THEN ISNULL(RTRIM(TrackingNo),'') ELSE ISNULL(RTRIM(UserDefine04),'') END     --(Wan07)
         --,@c_UserDefine04 = ISNULL(RTRIM(UserDefine04),'')                                                                                             --(Wan07)
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   IF @c_TrackingNo_ORD = '' --AND @c_UserDefine04 = ''     --(Wan07)
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
      SET TrackingNo    = @c_TrackingNo                     --(Wan07)
         --,UserDefine04  = @c_TrackingNo                   --(Wan07)             
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,Trafficcop = NULL
      WHERE Orderkey = @c_Orderkey
   END 

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60055
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERS Table. (isp_Ecom_PackConfirm)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   IF @c_TmpPickSlipNo <> '' 
   BEGIN
      DELETE PACKHEADER WITH (ROWLOCK)
      WHERE PickSlipNo = @c_TmpPickSlipNo

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60060  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKHEADER Table. (isp_Ecom_PackConfirm)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END
   END
   
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;   

   IF @@TRANCOUNT = 0 
      BEGIN TRAN;   

   EXEC nspGetRight 
      ''                   -- facility
   ,  @c_storerkey         -- Storerkey
   ,  null                 -- Sku
   ,  'AssignPackLabelToOrdCfg'       -- Configkey
   ,  @b_success           OUTPUT 
   ,  @c_PackLabelToOrd    OUTPUT 
   ,  @n_err               OUTPUT 
   ,  @c_errmsg            OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60065 
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_Ecom_PackConfirm)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END 

   IF @c_PackLabelToOrd = '1'
   BEGIN
      EXEC isp_AssignPackLabelToOrderByLoad
            @c_PickSlipNo= @c_PickSlipNo
         ,  @b_Success   = @b_Success  OUTPUT
         ,  @n_Err       = @n_Err      OUTPUT
         ,  @c_ErrMsg    = @c_ErrMsg   OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 60070
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                        + 'Error Executing isp_AssignPackLabelToOrderByLoad.(isp_Ecom_PackConfirm)'
         GOTO QUIT
      END
   END

   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;   

   IF @@TRANCOUNT = 0 
      BEGIN TRAN;   

   --(Wan06) Update PackHeader status to '9' before call ScanOutPickSlip - START
   UPDATE PACKHEADER WITH (ROWLOCK)
   SET Status = '9'
      ,estimatetotalctn= CASE WHEN @c_UpdateEstttlctn = '1' THEN @n_maxctn ELSE estimatetotalctn END        --(CS01)
      ,EditWho    = SUSER_NAME()
      ,EditDate   = GETDATE()
      ,archivecop = NULL
   WHERE PickSlipNo = @c_PickSlipNo

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60075
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKHEADER Table. (isp_Ecom_PackConfirm)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END
   --(Wan06) Update PackHeader status to '9' before call ScanOutPickSlip - END

   EXEC isp_ScanOutPickSlip  
               @c_PickSlipNo  = @c_PickSlipNo
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg    OUTPUT

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+':' + @c_errmsg
      SET @n_err = 60073 
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_ScanOutPickSlip. (isp_Ecom_PackConfirm)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   --(Wan03) - START
   SET @b_Success = 0    
   EXECUTE dbo.ispPackConfirmSerialNo   
           @c_PickSlipNo= @c_PickSlipNo  
         , @b_Success   = @b_Success     OUTPUT    
         , @n_Err       = @n_err         OUTPUT     
         , @c_ErrMsg    = @c_errmsg      OUTPUT    
  
   IF @n_err <> 0    
   BEGIN   
      SET @n_continue= 3   
      SET @n_err = 60080  
      SET @c_errmsg = CONVERT(char(5),@n_err)  
      SET @c_errmsg = 'NSQL'+CONVERT(char(6), @n_err)+ ': Execute ispPackConfirmSerialNo Failed. (isp_Ecom_PackConfirm) '   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
      GOTO QUIT                        
   END 

   --(Wan05) - START    
   SET @b_Success = 0        
   EXECUTE dbo.isp_PackConfirmQRF       
           @c_PickSlipNo= @c_PickSlipNo      
         , @b_Success   = @b_Success     OUTPUT        
         , @n_Err       = @n_err         OUTPUT         
       , @c_ErrMsg    = @c_errmsg      OUTPUT        
      
   IF @n_err <> 0        
   BEGIN       
      SET @n_continue= 3       
      SET @n_err = 60085      
      SET @c_errmsg = CONVERT(char(5),@n_err)      
      SET @c_errmsg = 'NSQL'+CONVERT(char(6), @n_err)+ ': Execute isp_PackConfirmQRF Failed. (isp_Ecom_PackConfirm) '       
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
      GOTO QUIT                            
   END     
   --(Wan05) - END    
    
   SET @b_Success = 0    
   EXECUTE dbo.ispPostPackConfirmWrapper   
           @c_PickSlipNo= @c_PickSlipNo  
         , @b_Success   = @b_Success     OUTPUT    
         , @n_Err       = @n_err         OUTPUT     
         , @c_ErrMsg    = @c_errmsg      OUTPUT    
         , @b_debug     = 0   
  
   IF @n_err <> 0    
   BEGIN   
      SET @n_continue= 3   
      SET @n_err = 60090  
      SET @c_errmsg = CONVERT(char(5),@n_err)  
      SET @c_errmsg = 'NSQL'+CONVERT(char(6), @n_err)+ ': Execute ispPostPackConfirmWrapper Failed. (isp_Ecom_PackConfirm) '   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '  
      GOTO QUIT                        
   END   
   --(Wan03) - END
       
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;   
      
   -- (Wan01) - START
   IF @@TRANCOUNT = 0
   BEGIN  
      BEGIN TRAN;   
   END

   DECLARE CUR_PTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef 
   FROM PACKTASKDETAIL WITH (NOLOCK)
   WHERE TaskBatchNo = @c_TaskBatchNo
   AND   Orderkey = @c_Orderkey

   OPEN CUR_PTD
   
   FETCH NEXT FROM CUR_PTD INTO @n_RowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE PACKTASKDETAIL WITH (ROWLOCK)
      SET Status     = '9'        
         ,PickSlipNo = @c_PickSlipNo
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
         ,TrafficCop = NULL
      WHERE RowRef = @n_RowRef 

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60080 
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKTASKDETAIL Table. (isp_Ecom_PackConfirm)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END

      FETCH NEXT FROM CUR_PTD INTO @n_RowRef
   END 
   CLOSE CUR_PTD
   DEALLOCATE CUR_PTD
    
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN;   
   END
   -- (Wan01) -  END
QUIT:
   -- (Wan01) -  START
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PTD') in (0 , 1)  
   BEGIN
      CLOSE CUR_PTD
      DEALLOCATE CUR_PTD
   END
   -- (Wan01) -  END

   -- (Wan03) -  START
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PACKD') in (0 , 1)  
   BEGIN
      CLOSE CUR_PACKD
      DEALLOCATE CUR_PACKD
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PACKL') in (0 , 1)  
   BEGIN
      CLOSE CUR_PACKL
      DEALLOCATE CUR_PACKL
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PACKSN') in (0 , 1)  
   BEGIN
      CLOSE CUR_PACKSN
      DEALLOCATE CUR_PACKSN
   END
   -- (Wan03) -  END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_Ecom_PackConfirm'
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
  
   WHILE @@TRANCOUNT < @n_StartTCnt 
      BEGIN TRAN;   
      
END -- procedure

GO