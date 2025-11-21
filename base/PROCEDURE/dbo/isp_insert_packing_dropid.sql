SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Insert_Packing_DropID                                   */
/* Creation Date: 06-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 16-JUN-2017 Wan01    1.1   WMS-1466 - Insert Dropid to refno2        */
/* 30-Aug-2017 TLTING   1.2   performance tune                          */
/* 25-Sep-2017 Wan02    1.3   WMS-3021 - CN&SG Logitech pack confirmation*/
/*                            trigger point                             */
/* 28-Sep-2017 Wan03    1.3   WMS-3062 - CN&SG Logitech Packing         */
/* 13-MAR-2020 Wan04    1.4   WMS-13254 - [CN]Logitech_Tote ID          */
/*                            Packing_pallet serialno_CR                */
/* 08-SEP-2020 Wan05    1.5   Fixed. Scan P, Serial # inserted but      */
/*                            TrackingID Not Updated                    */
/* 04-Aug-2021 WLChooi  1.6   WMS-17605 - Generate SSCC LabelNo (WL01)  */
/* 04-Aug-2021 WLChooi  1.6   DevOps Combine Script                     */
/* 22-Nov-2021 Wan07    1.7   WMS-18410 - [RG] Logitech Tote ID Packing */
/*                            Change Request                            */
/************************************************************************/
CREATE PROC [dbo].[isp_Insert_Packing_DropID] 
            @c_DropID      NVARCHAR(20)     
         ,  @c_Storerkey   NVARCHAR(15)   
         ,  @c_Sku         NVARCHAR(20) 
         ,  @c_SerialNo    NVARCHAR(30) = ''                 
         ,  @n_QtyPack     INT
         ,  @c_PickSlipNo  NVARCHAR(10)      OUTPUT  
         ,  @n_CartonNo    INT = 0           OUTPUT                                                
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
           @n_StartTCnt          INT
         , @n_Continue           INT
         , @n_Exists             INT
         , @b_packdetail_ins     INT   

         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_LabelNo            NVARCHAR(20)
         , @c_LabelLine          NVARCHAR(5)

         , @n_SerialQty          INT
         , @n_Qty                INT
   
         , @c_SerialNoKey        NVARCHAR(10)   
         , @c_ExternStatus_SN    NVARCHAR(10) 
         , @c_OrderLineNumber    NVARCHAR(5)

         , @c_LotNo              NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @c_Status             NVARCHAR(10)
         , @c_PrePackSerialNoSP  NVARCHAR(30)

         , @c_SQL                NVARCHAR(MAX)
         , @c_SQLParms           NVARCHAR(MAX)


         , @c_TraceName          NVARCHAR(80)
         , @dt_starttime         DATETIME
         , @dt_endtime           DATETIME
         , @dt_starttime1        DATETIME
         , @dt_endtime1          DATETIME
         , @c_Step1              NVARCHAR(20)
         , @c_Step2              NVARCHAR(20)
         , @c_Step3              NVARCHAR(20)
         , @c_Col1               NVARCHAR(20)
         , @c_Col2               NVARCHAR(20)
         , @c_Col3               NVARCHAR(20)
         , @c_Col5               NVARCHAR(20)

   --(Wan04) - START
   DECLARE @n_RowRef             INT = 0  
         , @n_TrackingIDKey      BIGINT = 0        -- 2020-07-02 
         , @b_packcomfirm        INT = 0           -- 2020-07-02
                            
         , @c_SerialNoType       NVARCHAR(1) = ''                 
         , @c_PackStatus         NVARCHAR(10)= ''
         , @c_ParentTrackingID   NVARCHAR(30)= ''  -- 2020-07-02
         , @c_PickMethod         NVARCHAR(10)= ''  -- 2020-07-02
         , @c_GenSSCCLabel       NVARCHAR(10)= ''  --WL01
      
         , @CUR_SN               CURSOR
         , @CUR_PSN              CURSOR            -- 2020-07-02
         , @CUR_MInP             CURSOR            -- 2020-07-02

   DECLARE @SCANSERIAL TABLE                                               
         (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY 
         ,  TrackingIDKey  BIGINT         NOT NULL DEFAULT(0)        --2020-07-02      
         ,  SerialNo       NVARCHAR(30)   NOT NULL                    
         ,  CartonNo       INT            NOT NULL DEFAULT(0)   
         ,  LabelLine      NVARCHAR(5)    NOT NULL DEFAULT('')  
         ,  Qty            INT            NOT NULL DEFAULT(0)  
         ,  PickSlipNo     NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Orderkey       NVARCHAR(10)   NOT NULL DEFAULT('') 
         ,  [Status]       NVARCHAR(1)    NOT NULL DEFAULT('0')      --P: Pack
         ) 
      
   --2020-07-02 - START     
   DECLARE @MInP TABLE                                               
         (  RowRef            INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  TrackingIDKey     BIGINT         NOT NULL DEFAULT(0)          
         ,  SerialNo          NVARCHAR(30)   NOT NULL    
         ,  ParentTrackingID  NVARCHAR(30)   NOT NULL DEFAULT('')          
         ) 
   --2020-07-02 - END       
   --(Wan04) - END
   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_TraceName = 'isp_Insert_Packing_DropID'
   SET @dt_starttime = GETDATE()
   SET @c_Col5 = SUSER_SNAME()

   IF @@TRANCOUNT = 0 
   BEGIN
      BEGIN TRAN
   END

   --WL01 S
   SELECT @c_GenSSCCLabel = ISNULL(SC.sValue,'')
   FROM STORERCONFIG SC (NOLOCK)
   WHERE SC.StorerKey = @c_Storerkey
   AND SC.ConfigKey = 'GenSSCCLabel'

   IF ISNULL(@c_GenSSCCLabel,'') = ''
      SET @c_GenSSCCLabel = ''
   --WL01 E

   --(Wan04) - START
   SET @c_SerialNo = ISNULL(@c_SerialNo,'')
   SET @c_SerialNoType = RIGHT(RTRIM(@c_SerialNo),1)

   IF @c_SerialNoType IN ('P')      
   BEGIN  
      INSERT INTO @SCANSERIAL ( TrackingIDKey, SerialNo, Qty )
      SELECT TID.TrackingIDKey
           , TID.TrackingID
           , TID.Qty 
      FROM TRACKINGID TID WITH (NOLOCK)
      WHERE TID.ParentTrackingID = @c_SerialNo
      AND   TID.Storerkey = @c_Storerkey
      AND   TID.PickMethod<> 'Loose'                     --2020-07-02
      AND   TID.[Status] >= 1 AND TID.[Status] <= 9      --2020-07-20
      ORDER BY TRACKINGID
   END
   ELSE
   BEGIN
      INSERT INTO @SCANSERIAL ( SerialNo, Qty )
      VALUES (@c_SerialNo, @n_QtyPack)

      IF @c_SerialNoType IN ('M') -- 2020-07-02
      BEGIN
         SET @c_ParentTrackingID = ''  
         SELECT TOP 1 @c_ParentTrackingID = ParentTrackingID
         FROM TRACKINGID TID WITH (NOLOCK)
         WHERE TID.TrackingID = @c_SerialNo
         AND   TID.Storerkey = @c_Storerkey
         AND   TID.[Status]  = '1'                       --2020-07-20        
         ORDER BY TrackingIDKey

         IF @c_ParentTrackingID <> ''
         BEGIN
            INSERT INTO @MInP ( TrackingIDKey, SerialNo, ParentTrackingID )
            SELECT TID.TrackingIDKey
                 , TID.TrackingID
                 , TID.ParentTrackingID 
            FROM TRACKINGID TID WITH (NOLOCK)
            WHERE TID.ParentTrackingID = @c_ParentTrackingID
            AND   TID.Storerkey = @c_Storerkey
            AND   TID.[Status]  = '1'                    --2020-07-20   
            ORDER BY TrackingIDKey
         END
      END -- 2020-07-02
   END
   --(Wan04) - END
   SET @c_Sku = UPPER(@c_Sku)                            --(Wan03)
   
   --(Wan04) - START
   SET @CUR_SN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef
         ,CartonNo = @n_CartonNo
         ,Qty = Qty
         ,SerialNo 
         ,TrackingIDKey                               --2020-07-02
   FROM @SCANSERIAL
   ORDER BY RowRef

   OPEN @CUR_SN

   FETCH NEXT FROM @CUR_SN INTO @n_RowRef
                              , @n_CartonNo
                              , @n_QtyPack
                              , @c_SerialNo
                              , @n_TrackingIDKey      --2020-07-02
                             
   WHILE @@FETCH_STATUS <> -1 AND @b_packcomfirm = 0  --2020-07-02
   BEGIN

      SET @c_SerialNo = UPPER(@c_SerialNo)
      SET @c_Orderkey = dbo.fnc_GetOrder_DropID (@c_DropID, @c_Storerkey, @c_Sku, @n_QtyPack)

      IF @c_Orderkey = '' 
      BEGIN
         --(Wan04) - START
         IF @c_SerialNoType = 'P'
         BEGIN
            GOTO NEXT_SERIAL
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60010 
            SET @c_errmsg='Pending Pack Order # Not found. (isp_Insert_Packing_DropID)' 
            GOTO QUIT_SP
         END
         --(Wan04) - END
      END

      SET @dt_starttime1 = GETDATE()

      SET @c_PickSlipNo = ''
      SET @c_PackStatus = '0'                               --(Wan04)
      SELECT @c_PickSlipNo = PickHeaderKey
            ,@c_PackStatus = Status                         --(Wan04)
      FROM PICKHEADER WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      --(Wan04) - START
      IF @c_PickSlipNo <> '' AND @c_PackStatus = '9'
      BEGIN
         GOTO NEXT_SERIAL
      END
  
      IF @c_PickSlipNo <> '' AND @c_PackStatus = '0'
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM SERIALNO SN WITH (NOLOCK)
                     WHERE SN.SerialNo  = @c_SerialNo
                     AND   SN.Storerkey = @c_Storerkey
                     AND   SN.PickSlipNo= @c_PickSlipNo
                     AND   SN.ExternStatus NOT IN ('0', 'CANC') 
                     )
         BEGIN            
            GOTO PACK_CONFIRM
         END    
      END    
      --(Wan04) - END

      --(Wan05) - START
      IF @@TRANCOUNT = 0 
      BEGIN
         BEGIN TRAN
      END
      --(Wan05) - END

      IF @c_PickSlipNo = ''
      BEGIN
         EXECUTE nspg_GetKey 
                 @KeyName     = 'PICKSLIP'
               , @fieldlength = 9
               , @keystring   = @c_PickSlipNo  OUTPUT
               , @b_success   = @b_success     OUTPUT
               , @n_err       = @n_err         OUTPUT
               , @c_errmsg    = @c_errmsg      OUTPUT
               , @b_resultset = 0
               , @n_batch     = 1
      
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 60020                                                                                           
            SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (isp_Insert_Packing_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                          
            GOTO QUIT_SP         
         END

         SET @c_PickSlipNo = 'P' + @c_PickSlipNo

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
            SET @n_err = 60030 
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PICKHEADER Table. (isp_Insert_Packing_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END
      END

      IF NOT EXISTS (   SELECT 1
                        FROM PICKINGINFO WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo
                     )
      BEGIN
         INSERT INTO PICKINGINFO 
            (  PickSlipNo
            ,  ScanInDate
            ,  ScanOutDate
            ,  PickerID
            --,  TrafficCop         -- Fixed for Order status update to '3' 
            )
         VALUES 
            (  @c_PickSlipNo
            ,  GETDATE()
            ,  NULL
            ,  SUSER_NAME()
            --,  NULL               -- Fixed for Order status update to '3'
            )

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60040  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PICKINGINFO Table. (isp_Insert_Packing_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END
      END
      
      IF NOT EXISTS (   SELECT 1
                        FROM PACKHEADER WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo
                     )
      BEGIN
         INSERT INTO PACKHEADER 
            (  PickSlipNo
            ,  Storerkey
            ,  Orderkey
            ,  Route
            ,  OrderRefNo
            ,  LoadKey
            ,  ConsigneeKey
            ,  Status
            ,  CartonGroup
            ,  ManifestPrinted
            ,  ConsoOrderKey
            )
         SELECT 
               @c_PickSlipNo
            ,  ORDERS.Storerkey
            ,  ORDERS.Orderkey
            ,  ORDERS.Route
            ,  ORDERS.ExternOrderKey
            ,  ORDERS.LoadKey
            ,  ORDERS.ConsigneeKey
            ,  '0'
            ,  STORER.CartonGroup
            ,  ''
            ,  ''
         FROM ORDERS WITH (NOLOCK)
         JOIN STORER WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
         WHERE ORDERS.Orderkey = @c_Orderkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60050  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PACKHEADER Table. (isp_Insert_Packing_DropID)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END
      END

      SET @b_packdetail_ins = 0
      SET @c_LabelNo = ''
      IF @n_CartonNo = 0
      BEGIN
         --Wan07 - START
         --SELECT @n_CartonNo = ISNULL(MAX(CartonNo),0) + 1
         --FROM PACKDETAIL WITH (NOLOCK)
         --WHERE PickSlipNo = @c_PickSlipNo

         --SET @c_LabelLine = '00001'
         SET @c_LabelLine = ''
         --Wan07 - END
         SET @b_packdetail_ins = 1
      END
      ELSE 
      BEGIN
         SET @c_LabelLine = ''
         SELECT @c_LabelNo   = LabelNo
               ,@c_LabelLine = LabelLine
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND   CartonNo = @n_CartonNo
         AND   Storerkey= @c_Storerkey
         AND   Sku = @c_Sku
         AND   DropID = @c_DropID

         IF @c_LabelLine = ''
         BEGIN
            SELECT @c_LabelNo  = ISNULL(MAX(LabelNo),'')
               ,   @c_LabelLine= RIGHT('00000' + CONVERT(NVARCHAR(5), CONVERT(INT, ISNULL(MAX(LabelLine),0)) + 1),5)
            FROM PACKDETAIL WITH (NOLOCK) 
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo = @n_CartonNo

            SET @b_packdetail_ins = 1
         END
      END

      IF @b_packdetail_ins = 1
      BEGIN
         IF @c_LabelNo = ''
         BEGIN
            --WL01 S
            IF @c_GenSSCCLabel IN ('1','2')
            BEGIN
               EXEC isp_GenSSCCLabel_Wrapper  
                     @c_PickSlipNo     = @c_PickSlipNo
                  ,  @n_CartonNo       = @n_CartonNo
                  ,  @c_SSCC_LabelNo   = @c_LabelNo   OUTPUT

               SELECT @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60061 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenSSCCLabel_Wrapper. (isp_Insert_Packing_DropID)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                  GOTO QUIT_SP
               END
            END
            ELSE
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
                  SET @n_err = 60060 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (isp_Insert_Packing_DropID)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                  GOTO QUIT_SP
               END
            END
            --WL01 E
         END

         INSERT INTO PACKDETAIL
            (  PickSlipNo
            ,  CartonNo
            ,  LabelNo
            ,  LabelLine
            ,  Storerkey
            ,  Sku
            ,  Qty
            ,  DropID
            ,  RefNo2                     --(Wan01)
            )
         VALUES 
            (  @c_PickSlipNo
            ,  @n_CartonNo
            ,  @c_LabelNo
            ,  @c_LabelLine
            ,  @c_Storerkey
            ,  @c_Sku                     
            ,  @n_QtyPack
            ,  @c_DropID
            ,  @c_DropID                  --(Wan01)
            )

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60070  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PACKDETAIL Table. (isp_Insert_Packing_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END
         
         --(Wan07) - START
         IF @n_CartonNo = 0
         BEGIN
            SELECT TOP 1 @n_CartonNo = pd.CartonNo
                     , @c_LabelLine = pd.LabelLine
            FROM dbo.PackDetail AS pd (NOLOCK)
            WHERE pd.PickSlipNo = @c_PickSlipNo
            AND pd.LabelNo = @c_LabelNo
            ORDER BY pd.LabelLine DESC
         END
         --(Wan07) - END
      END
      ELSE
      BEGIN
         UPDATE PACKDETAIL WITH (ROWLOCK)
         SET Qty = Qty + @n_QtyPack
           , EditWho = SUSER_NAME()
           , EditDate = GETDATE()
           , ArchiveCop = NULL
         WHERE PickSlipNo = @c_PickSlipNo
         AND   CartonNo = @n_CartonNo
         AND   LabelLine = @c_LabelLine

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60080  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error UPDATE PACKDETAIL Table. (isp_Insert_Packing_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END
      END

      SET @c_Step1 = 'PACKDETAIL'
      SET @dt_Endtime1 = GETDATE()
      SET @c_Col1 = RIGHT(CONVERT(CHAR(12),@dt_starttime1, 114),9) + '-' + RIGHT(CONVERT(CHAR(12),@dt_Endtime1, 114),9)

      IF ISNULL(@c_SerialNo,'') <> ''
      BEGIN
         SET @dt_Starttime1 = GETDATE()
     
         IF OBJECT_ID('tempdb..#TMP_SNInfo','U') IS NULL
         BEGIN
            CREATE TABLE #TMP_SNInfo  
               (  SerialNo       NVARCHAR(20)   NOT NULL DEFAULT('')  PRIMARY KEY
               ,  LotNo          NVARCHAR(10)   NULL DEFAULT('')
               ,  ID             NVARCHAR(18)   NULL DEFAULT('')
               ,  ExternStatus   NVARCHAR(10)   NULL DEFAULT('0')
               ,  Status         NVARCHAR(10)   NULL DEFAULT('0')
               )
         END
         --(Wan04) - START
         ELSE
         BEGIN
            TRUNCATE TABLE #TMP_SNInfo
         END
         
         IF @c_PrePackSerialNoSP <> ''
         BEGIN
            SET @c_PrePackSerialNoSP = ''
            SELECT @c_PrePackSerialNoSP = ISNULL(RTRIM(SValue),'')
            FROM STORERCONFIG WITH (NOLOCK)
            WHERE Storerkey = @c_StorerKey
            AND   Configkey = 'PrePackSerialNo_Wrapper'
         END
         --(Wan04) - END
         
         IF EXISTS (SELECT 1 FROM sys.objects o WITH (NOLOCK) WHERE NAME = @c_PrePackSerialNoSP AND TYPE = 'P')
         BEGIN

            SET @c_SQL = N'EXECUTE ' + @c_PrePackSerialNoSP  
                       + '  @c_PickSlipNo = @c_PickSlipNo' 
                       + ', @c_SerialNo   = @c_SerialNo'                        
                       + ', @c_Storerkey  = @c_Storerkey'  
                       + ', @c_Sku        = @c_Sku'                      
                       + ', @b_Success  = @b_Success     OUTPUT' 
                       + ', @n_Err      = @n_Err         OUTPUT'  
                       + ', @c_ErrMsg   = @c_ErrMsg      OUTPUT'  


            SET @c_SQLParms= N'@c_PickSlipNo          NVARCHAR(10)'  
                           +  ',@c_SerialNo           NVARCHAR(30)' 
                           +  ',@c_Storerkey          NVARCHAR(15)'  
                           +  ',@c_Sku                NVARCHAR(20)'                                                                            
                           +  ',@b_Success            INT OUTPUT'
                           +  ',@n_Err                INT OUTPUT'
                           +  ',@c_ErrMsg             NVARCHAR(250) OUTPUT ' 
                                   
            EXEC sp_ExecuteSQL @c_SQL
                           ,   @c_SQLParms
                           ,   @c_PickSlipNo
                           ,   @c_SerialNo
                           ,   @c_Storerkey
                           ,   @c_Sku
                           ,   @b_Success OUTPUT
                           ,   @n_Err     OUTPUT
                           ,   @c_ErrMsg  OUTPUT 
     
            IF @@ERROR <> 0 OR @b_Success <> 1  
            BEGIN  
               SET @n_Continue= 3    
               SET @n_Err     = 60090    
               SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PrePackSerialNoSP 
                              + CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_Insert_Packing_DropID)'
               GOTO QUIT_SP                          
            END 
         END

         SET @c_LotNo = ''
         SET @c_ID    = ''
         SET @c_ExternStatus_SN = '0'
         SET @c_Status = '0'

         SELECT TOP 1
               @c_LotNo = ISNULL(RTRIM(LotNo), '')
            ,  @c_ID    = ISNULL(RTRIM(ID), '')
            ,  @c_ExternStatus_SN = ISNULL(RTRIM(ExternStatus), '')
            ,  @c_Status    = ISNULL(RTRIM(Status), '')
         FROM #TMP_SNInfo
         WHERE SerialNo = @c_SerialNo


         DECLARE CUR_SER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PICK_ORD.OrderLineNumber
               ,Qty = PICK_ORD.QtyAllocated - ISNULL(SER.Qty,0)
         FROM (   SELECT PD.OrderLineNumber
                        ,QtyAllocated = ISNULL(SUM(PD.Qty),0)
                  FROM PICKDETAIL PD WITH (NOLOCK)
                  WHERE PD.Orderkey = @c_Orderkey
                  AND PD.Storerkey = @c_Storerkey
                  AND PD.Sku = @c_Sku
                  AND PD.DropID = @c_DropID
                  GROUP BY PD.OrderLineNumber
              ) PICK_ORD
         LEFT JOIN ( SELECT SER.OrderLineNumber
                           ,Qty = ISNULL(SUM(SER.Qty),0)
                     FROM SERIALNO   SER WITH (NOLOCK) 
                     JOIN PACKDETAIL PD  WITH (NOLOCK) ON (SER.PickSlipNo = PD.PickSlipNo)
                                                       AND(SER.CartonNo   = PD.CartonNo)
                                                       AND(SER.LabelLine  = PD.LabelLine)
                                                       AND(SER.Storerkey  = PD.Storerkey)
                                                       AND(SER.Sku        = PD.Sku)
                     WHERE SER.Orderkey = @c_Orderkey
                     AND SER.Storerkey = @c_Storerkey
                     AND SER.Sku = @c_Sku
                     AND PD.DropID = @c_DropID
                     AND SER.ExternStatus <> 'CANC' 
                     GROUP BY SER.OrderLineNumber
                  ) SER ON  (PICK_ORD.OrderLineNumber = SER.OrderLineNumber)
         WHERE PICK_ORD.QtyAllocated - ISNULL(SER.Qty,0) > 0

         OPEN CUR_SER
      
         FETCH NEXT FROM CUR_SER INTO @c_OrderLineNumber
                                    , @n_SerialQty
         WHILE @@FETCH_STATUS <> -1 AND @n_QtyPack > 0 
         BEGIN
            SET @n_Qty = @n_QtyPack

            IF @n_QtyPack > @n_SerialQty
            BEGIN
               SET @n_Qty = @n_SerialQty
            END

            SET @n_QtyPack = @n_QtyPack - @n_Qty

            EXECUTE nspg_GetKey 
                    @KeyName     = 'SERIALNO'
                  , @fieldlength = 10
                  , @keystring   = @c_SerialNoKey  OUTPUT
                  , @b_success   = @b_success     OUTPUT
                  , @n_err       = @n_err         OUTPUT
                  , @c_errmsg    = @c_errmsg      OUTPUT
                  , @b_resultset = 0
                  , @n_batch     = 1
      
     
            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3                                                                                              
               SET @n_err = 60100                                                                                         
               SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (isp_Insert_Packing_DropID)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                          
               GOTO QUIT_SP        
            END
                                
            INSERT INTO SERIALNO
               (  SerialNoKey
               ,  SerialNo
               ,  Orderkey
               ,  OrderLineNumber
               ,  Storerkey
               ,  Sku
               ,  Qty
               ,  LotNo
               ,  ID
               ,  Status
               ,  ExternStatus
               ,  PickSlipNo
               ,  CartonNo
               ,  LabelLine
               )
            VALUES 
               (  @c_SerialNoKey
               ,  @c_SerialNo
               ,  @c_Orderkey
               ,  @c_OrderLineNumber
               ,  @c_Storerkey
               ,  @c_Sku
               ,  @n_Qty 
               ,  @c_LotNo
               ,  @c_ID
               ,  @c_Status
               ,  @c_ExternStatus_SN
               ,  @c_PickSlipNo
               ,  @n_CartonNo
               ,  @c_LabelLine
               )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60110  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into SERIALNO Table. (isp_Insert_Packing_DropID)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END

            --(Wan05) - Move out the Loop as there is 1 serialno - START
            --(Wan04) - START 2020-07-02 
            --IF EXISTS (SELECT 1 FROM @MInP)
            --BEGIN
            --   SET @CUR_MInP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            --   SELECT TrackingIDKey
            --   FROM @MInP

            --   OPEN @CUR_MInP

            --   FETCH NEXT FROM @CUR_MInP INTO @n_TrackingIDKey

            --   WHILE @@FETCH_STATUS <> -1
            --   BEGIN
            --      UPDATE TRACKINGID
            --         SET [Status]   = '9'
            --            ,PickMethod = 'Loose'
            --            ,EditWho    = SUSER_SNAME()
            --            ,EditDate   = GETDATE()
            --            ,TrafficCop = NULL
            --      WHERE TrackingIDKey = @n_TrackingIDKey
            --      AND   [Status] = '1'                      --2020-07-20

            --      SET @n_err = @@ERROR
            --      IF @n_err <> 0
            --      BEGIN
            --         SET @n_continue = 3
            --         SET @n_err = 60115
            --         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update TRACKINGID Table. (isp_Insert_Packing_DropID)' 
            --                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            --         GOTO QUIT_SP
            --      END
            --      FETCH NEXT FROM @CUR_MInP INTO @n_TrackingIDKey
            --   END
            --   CLOSE @CUR_MInP
            --   DEALLOCATE @CUR_MInP
            --END
            --(Wan04) - END 2020-07-02
            --(Wan05) - END

            FETCH NEXT FROM CUR_SER INTO @c_OrderLineNumber
                                       , @n_SerialQty
         END 
         CLOSE CUR_SER
         DEALLOCATE CUR_SER
      END 
      SET @c_Step2 = 'Serial#'
      SET @dt_Endtime1 = GETDATE()
      SET @c_Col2 = RIGHT(CONVERT(CHAR(12),@dt_starttime1, 114),9) + '-' + RIGHT(CONVERT(CHAR(12),@dt_Endtime1, 114),9)

      --(Wan05) - START
      IF EXISTS (SELECT 1 FROM @MInP)
      BEGIN
         SET @CUR_MInP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TrackingIDKey
         FROM @MInP

         OPEN @CUR_MInP

         FETCH NEXT FROM @CUR_MInP INTO @n_TrackingIDKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE TRACKINGID
               SET [Status]   = '9'
                  ,PickMethod = 'Loose'
                  ,EditWho    = SUSER_SNAME()
                  ,EditDate   = GETDATE()
                  ,TrafficCop = NULL
            WHERE TrackingIDKey = @n_TrackingIDKey
            AND   [Status] = '1'                      

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60115
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update TRACKINGID Table. (isp_Insert_Packing_DropID)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END
            FETCH NEXT FROM @CUR_MInP INTO @n_TrackingIDKey
         END
         CLOSE @CUR_MInP
         DEALLOCATE @CUR_MInP
      END

      IF @c_SerialNoType = 'P'
      BEGIN
         SET @c_PickMethod = 'Full'
         SET @CUR_PSN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TrackingIDKey
         FROM @SCANSERIAL

         OPEN @CUR_PSN

         FETCH NEXT FROM @CUR_PSN INTO @n_TrackingIDKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE TRACKINGID
               SET [Status]   = '9'
                  ,PickMethod = @c_PickMethod
                  ,EditWho    = SUSER_SNAME()
                  ,EditDate   = GETDATE()
                  ,TrafficCop = NULL
            WHERE TrackingIDKey = @n_TrackingIDKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60135
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update TRACKINGID Table. (isp_Insert_Packing_DropID)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END
            FETCH NEXT FROM @CUR_PSN INTO @n_TrackingIDKey
         END
         CLOSE @CUR_PSN
         DEALLOCATE @CUR_PSN
      END
      --(Wan05) - END

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN;
      END;

      PACK_CONFIRM:
      SET @n_Exists = 0; --2020-09-18
      WITH 
      PICK_ORD( Orderkey, Storerkey, Sku, QtyAllocated)
      AS (  SELECT OD.Orderkey, OD.Storerkey, OD.Sku, QtyAllocated = ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
            FROM ORDERDETAIL OD WITH (NOLOCK)
            WHERE OD.Orderkey = @c_Orderkey
            GROUP BY OD.Orderkey, OD.Storerkey, OD.Sku
         )
      ,
      PACK_ORD( Orderkey, Storerkey, Sku, QtyPacked)
      AS (  SELECT @c_Orderkey, PD.Storerkey, PD.Sku, QtyPacked = ISNULL(SUM(PD.Qty),0)
            FROM PACKDETAIL PD WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            GROUP BY PD.Storerkey, PD.Sku
         )

      SELECT @n_Exists = 1 
      FROM PICK_ORD
      LEFT JOIN PACK_ORD ON  (PICK_ORD.Orderkey = PACK_ORD.Orderkey)
                         AND (PICK_ORD.Storerkey= PACK_ORD.Storerkey) 
                         AND (PICK_ORD.Sku      = PACK_ORD.Sku)                         
      WHERE PICK_ORD.QtyAllocated > ISNULL(PACK_ORD.QtyPacked,0)
      
      IF @n_Exists = 1
      BEGIN
         GOTO NEXT_SERIAL                    --(Wan04)
      END 

      SET @dt_Starttime1 = GETDATE()
      ----------------------------------------------------
      -- PickSLipNo PACK Confirm if Order finished packked
      ----------------------------------------------------
      IF @@TRANCOUNT = 0 
      BEGIN
         BEGIN TRAN;
      END;

      EXEC isp_ScanOutPickSlip  
                  @c_PickSlipNo  = @c_PickSlipNo
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         --SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+':' + @c_errmsg
         SET @n_err = 60120
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_ScanOutPickSlip. (isp_Insert_Packing_DropID)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      UPDATE PACKHEADER WITH (ROWLOCK)
      SET Status = '9'
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
         ,archivecop = NULL
      WHERE PickSlipNo = @c_PickSlipNo

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60130
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKHEADER Table. (isp_Insert_Packing_DropID)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      --(Wan02) - START
      EXEC isp_PickPackCfm_ITF  
                  @c_Storerkey   = @c_Storerkey
               ,  @c_PickSlipNo  = @c_PickSlipNo
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60140
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_PackConfirm_ITF. (isp_Insert_Packing_DropID)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END
      --(Wan02) - END

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN;  
      END 

      SET @b_packcomfirm = 1  -- 2020-07-02
      SET @c_Step3 = 'PACKCONFIRM'
      SET @dt_Starttime1 = GETDATE()
      SET @c_Col3 = RIGHT(CONVERT(CHAR(12),@dt_starttime1, 114),9) + '-' + RIGHT(CONVERT(CHAR(12),@dt_Endtime1, 114),9)
      
      NEXT_SERIAL:
      --(Wan04) - START
      IF ISNULL(@c_PickSlipNo,'') = ''
      BEGIN
         SELECT TOP 1 
                @c_PickSlipNo = SN.PickSlipNo
               ,@c_Orderkey = SN.Orderkey
         FROM SERIALNO SN WITH (NOLOCK)
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = SN.PickSlipNo 
                                          AND PD.CartonNo = SN.CartonNo 
                                          AND PD.LabelLine = SN.LabelLine
         WHERE SerialNo = @c_SerialNo
         AND SN.Storerkey = @c_Storerkey
         AND SN.[Status] < '9'
         AND SN.PickSlipNo > ''
         AND SN.Orderkey > ''
         AND PD.DropID = @c_DropID
      END

      IF @c_PickSlipNo > ''
      BEGIN
         UPDATE @SCANSERIAL
         SET PickSlipNo= @c_PickSlipNo
         ,   Orderkey = @c_Orderkey
         ,   [Status] = 'P'            --2020-07-02
         WHERE RowRef = @n_RowRef
      END
      --(Wan04) - END            
      
      FETCH NEXT FROM @CUR_SN INTO @n_RowRef
                                 , @n_CartonNo
                                 , @n_QtyPack
                                 , @c_SerialNo
                                 , @n_TrackingIDKey   --2020-07-02
   END
   CLOSE @CUR_SN
   DEALLOCATE @CUR_SN
   --(Wan04) - END

   IF OBJECT_ID('tempdb..#TMP_SNInfo','U') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_SNInfo
   END

   --(Wan04) - START
   IF @c_SerialNoType = 'P'
   BEGIN
   --(Wan05) - START - MOve up before Pack confirm
   --   --(Wan04) - START 2020-07-02
   --   SET @c_PickMethod = 'Full'
   --   SELECT TOP 1 @c_PickMethod = 'Loose'
   --   FROM @SCANSERIAL
   --   WHERE [Status] <> 'P'

   --   SET @CUR_PSN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --   SELECT TrackingIDKey
   --   FROM @SCANSERIAL

   --   OPEN @CUR_PSN

   --   FETCH NEXT FROM @CUR_PSN INTO @n_TrackingIDKey

   --   WHILE @@FETCH_STATUS <> -1
   --   BEGIN
   --      UPDATE TRACKINGID
   --         SET [Status]   = '9'
   --            ,PickMethod = @c_PickMethod
   --            ,EditWho    = SUSER_SNAME()
   --            ,EditDate   = GETDATE()
   --            ,TrafficCop = NULL
   --      WHERE TrackingIDKey = @n_TrackingIDKey

   --      SET @n_err = @@ERROR
   --      IF @n_err <> 0
   --      BEGIN
   --         SET @n_continue = 3
   --         SET @n_err = 60135
   --         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update TRACKINGID Table. (isp_Insert_Packing_DropID)' 
   --                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
   --         GOTO QUIT_SP
   --      END
   --      FETCH NEXT FROM @CUR_PSN INTO @n_TrackingIDKey
   --   END
   --   CLOSE @CUR_PSN
   --   DEALLOCATE @CUR_PSN
   --   --(Wan04) - END   2020-07-02
   -- (Wan05) - END

      SELECT TOP 1 @c_PickSlipNo = SS.PickSlipNo
      FROM @SCANSERIAL SS
      WHERE PickSlipNo > ''
      ORDER BY RowRef
   END
   --(Wan04) - END
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
      SET @dt_endtime = GETDATE()

      --EXEC isp_InsertTraceInfo
      --  @c_TraceCode ='TOTE_PACKING'
      --, @c_TraceName = @c_TraceName
      --, @c_starttime = @dt_starttime
      --, @c_endtime   = @dt_endtime
      --, @c_step1     = @c_step1 
      --, @c_step2     = @c_step2  
      --, @c_step3     = @c_step3  
      --, @c_step4     = '' 
      --, @c_step5     = ''
      --, @c_col1      = @c_col1 
      --, @c_col2      = @c_col2 
      --, @c_col3      = @c_col3 
      --, @c_col4      = 'ERROR'
      --, @c_col5      = @c_col5 
      --, @b_Success   = @b_Success      
      --, @n_Err       = @n_Err          
      --, @c_ErrMsg    = @c_ErrMsg      

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_Insert_Packing_DropID'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END

      SET @dt_endtime = GETDATE()

      --EXEC isp_InsertTraceInfo
      --  @c_TraceCode ='TOTE_PACKING'
      --, @c_TraceName = @c_TraceName
      --, @c_starttime = @dt_starttime
      --, @c_endtime   = @dt_endtime
      --, @c_step1     = @c_step1 
      --, @c_step2     = @c_step2  
      --, @c_step3     = @c_step3  
      --, @c_step4     = '' 
      --, @c_step5     = ''
      --, @c_col1      = @c_col1 
      --, @c_col2      = @c_col2 
      --, @c_col3      = @c_col3 
      --, @c_col4      = 'PASS'
      --, @c_col5      = @c_col5 
      --, @b_Success   = @b_Success      
      --, @n_Err       = @n_Err          
      --, @c_ErrMsg    = @c_ErrMsg      
   END
  
   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN; 
   END  
END -- procedure

GO