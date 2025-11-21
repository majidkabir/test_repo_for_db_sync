SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_MAST_AutoWavePackShip                             */
/* Creation Date: 02-Jun-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-22668 - CN MAST Exceed script for auto ship (orders)       */
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 02-Jun-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[isp_MAST_AutoWavePackShip]    
(
   @c_Storerkey     NVARCHAR(15) = '18455',
   @c_Recipients    NVARCHAR(2000) = '' --email address delimited by ;
)
AS  
BEGIN  	
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success            INT,
           @n_Err                INT,
           @c_ErrMsg             NVARCHAR(255),
           @n_Continue           INT,
           @n_StartTranCount     INT
   
   DECLARE @c_GetOrderkey        NVARCHAR(10),
           @c_GetPickslipno      NVARCHAR(10),
           @c_GetSKU             NVARCHAR(20),
           @n_GetQty             INT,
           @c_GetLabelNo         NVARCHAR(20),
           @c_LabelLine          NVARCHAR(5) = '00000',
           @n_LabelLineCNT       INT = 0,
           @c_OrderStatus        NVARCHAR(1),
           @c_GetMBOLKey         NVARCHAR(10)

   DECLARE @dt_OrderDate         DATETIME
         , @dt_Delivery_Date     DATETIME
         , @c_Route              NVARCHAR(10)
         , @n_totweight          DECIMAL(20,4)
         , @n_totcube            DECIMAL(20,4)
         , @c_ExternOrderkey     NVARCHAR(50)
         , @c_Loadkey            NVARCHAR(10)
         , @b_ReturnCode         INT
         , @c_GetReason          NVARCHAR(255)
         , @b_debug              INT = 0
         , @n_TotLines           INT = 0
         , @n_Custcnt            INT = 0
         , @n_Rdscnt             INT = 0

   DECLARE @c_AutoUpdSuperOrderFlag        NVARCHAR(10)
         , @c_SuperOrderFlag               NVARCHAR(10)
         , @c_AutoUpdLoadDefaultStorerStrg NVARCHAR(10)
         , @c_GetLoadkey                   NVARCHAR(10)

   DECLARE @c_Body         NVARCHAR(MAX),          
           @c_Subject      NVARCHAR(255),          
           @c_Date         NVARCHAR(20),           
           @c_SendEmail    NVARCHAR(1)

   DECLARE @c_ConsigneeKey     NVARCHAR(20) = ''  
         , @c_Priority         NVARCHAR(10) = '9' 
         , @c_OrderType        NVARCHAR(10) = ''  
         , @c_Door             NVARCHAR(10) = ''  
         , @c_DeliveryPlace    NVARCHAR(30) = ''  
         , @c_CustomerName     NVARCHAR(100) = ''
         , @c_Wavekey          NVARCHAR(10) = ''
         , @c_Wavedetailkey    NVARCHAR(10) = ''
         , @c_Facility         NVARCHAR(5) = 'VSZTO'
         , @c_Type             NVARCHAR(10) = 'WD'
         , @c_Status           NVARCHAR(10) = '2'

   DECLARE @c_Authority NVARCHAR(30)
         , @c_Option2   NVARCHAR(50)
    
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT
         
   IF @n_continue = 1 or @n_continue = 2
   BEGIN 
      CREATE TABLE #TMP_ORDERS (  
         Orderkey   NVARCHAR(10)
      ) 
      
      CREATE TABLE #TMP_RESULT (  
         Orderkey   NVARCHAR(10)
       , Reason     NVARCHAR(255)
      ) 
           
   END

   INSERT INTO #TMP_ORDERS (Orderkey)
   SELECT DISTINCT OH.Orderkey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.StorerKey = @c_Storerkey
   AND OH.[Status] = @c_Status
   AND OH.Facility = @c_Facility
   AND LEFT(TRIM(OH.[Type]), 2) = @c_Type

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Orderkey
      FROM #TMP_ORDERS

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetOrderkey

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      SET @c_GetPickslipno = ''
      SET @n_LabelLineCNT  = 0
      SET @c_OrderStatus   = ''
      SET @c_GetMBOLKey    = ''
      SET @c_Authority     = ''

      SELECT @c_Storerkey = StorerKey
           , @c_Facility  = Facility
      FROM ORDERS (NOLOCK)
      WHERE Orderkey = @c_GetOrderkey

      /*
      --Allocation
      IF @n_Continue IN (1,2)
      BEGIN
         EXEC [nsp_OrderProcessing_Wrapper]  
            @c_OrderKey        = @c_GetOrderkey
          , @c_oskey           = ''
          , @c_docarton        = ''
          , @c_doroute         = ''
          , @c_tblprefix       = ''
          , @c_extendparms     = ''
          , @c_StrategykeyParm = ''
         
         IF @@ERROR <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Allocation Failed'
         
            GOTO NEXT_LOOP
         END

         SELECT @c_OrderStatus = [Status]
              , @c_Storerkey   = StorerKey
         FROM ORDERS (NOLOCK)
         WHERE Orderkey = @c_GetOrderkey

         IF @c_OrderStatus = '0'
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Not Allocated'
         
            GOTO NEXT_LOOP
         END
         ELSE IF @c_OrderStatus = '1'
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Partially Allocated'
         
            GOTO NEXT_LOOP
         END
      END*/

      --Create Load
      IF @n_Continue IN (1,2)
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
                'LoadKey',
                10,
                @c_GetLoadkey OUTPUT,
                @b_success    OUTPUT,
                @n_err        OUTPUT,
                @c_errmsg     OUTPUT
         
         IF @b_success <> 1
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Getting LoadKey'
         
            GOTO NEXT_LOOP
         END

         SELECT @n_totcube   = SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt)
              , @n_totweight = SUM(ORDERDETAIL.OpenQty * SKU.StdCube)
              , @n_Custcnt   = COUNT(DISTINCT ORDERS.C_Company)
              , @n_Rdscnt    = ISNULL(MAX(CASE WHEN ORDERS.Rds = 'Y' THEN 1 ELSE 0 END),0)
              , @c_Facility  = MAX(ORDERS.Facility)
              , @n_TotLines  = COUNT(DISTINCT ORDERDETAIL.OrderLineNumber)
         FROM ORDERS (NOLOCK)
         JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
         JOIN SKU (NOLOCK) ON SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.SKU = ORDERDETAIL.Sku
         WHERE ORDERS.OrderKey = @c_GetOrderkey

         SET @c_AutoUpdSuperOrderFlag = ''                                                               
                                                            
         SELECT TOP 1 @c_AutoUpdSuperOrderFlag = ISNULL(RTRIM(Svalue),'')                                                                                            
         FROM StorerConfig sc WITH (NOLOCK)                                                                                                                          
         WHERE sc.ConfigKey = 'AutoUpdSupOrdflag'                                                                                                                    
         AND sc.StorerKey = @c_Storerkey                                                                                                                           
         AND sc.Facility = CASE WHEN ISNULL(RTRIM(sc.Facility), '') = '' THEN sc.Facility ELSE @c_Facility END     
                                                         
         IF @c_AutoUpdSuperOrderFlag = ''                                                                                                                            
         BEGIN                                                                                                                                                       
            SELECT TOP 1 @c_AutoUpdSuperOrderFlag = ISNULL(RTRIM(Svalue),'')                                                                                         
            FROM StorerConfig sc WITH (NOLOCK)                                                                                                                       
            WHERE sc.ConfigKey = 'AutoUpdSupOrdflag'                                                                                                                 
            AND sc.StorerKey = @c_Storerkey                                                                                                                        
         END              
                                                                                                                                        
         SET @c_AutoUpdLoadDefaultStorerStrg = ''     
                                                                                                                        
         SELECT TOP 1 @c_AutoUpdLoadDefaultStorerStrg = ISNULL(RTRIM(Svalue),'0') 
         FROM StorerConfig sc WITH (NOLOCK)                                                                                                                          
         WHERE sc.ConfigKey = 'AutoUpdLoadDefaultStorerStrg'                                                                                                         
         AND sc.StorerKey = @c_Storerkey                                                                                                                           
         AND sc.Facility = CASE WHEN ISNULL(RTRIM(sc.Facility), '') = '' THEN sc.Facility ELSE @c_Facility END                                                     
  
         IF @c_AutoUpdSuperOrderFlag = '1'                                                                                                                        
         BEGIN                                                                                                                                                    
            IF @n_Rdscnt > 0                                                                                                                        
               SET @c_SuperOrderFlag = 'N'                                                                                                                       
            ELSE                                                                                                                                                  
               SET @c_SuperOrderFlag = 'Y'                                                                                                             
         END  
         
         INSERT INTO LoadPlan(LoadKey, Facility, CustCnt, OrderCnt, [Weight], [Cube], SuperOrderFlag, DefaultStrategykey) 
         VALUES (@c_GetLoadkey, @c_Facility, @n_Custcnt, 1, @n_totweight, @n_totcube, @c_SuperOrderFlag, CASE WHEN @c_AutoUpdLoadDefaultStorerStrg = '1' THEN 'Y' END)

         SELECT @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Inserting Loadplan'
         
            GOTO NEXT_LOOP
         END

         SELECT @c_ConsigneeKey   = ConsigneeKey   
              , @c_Priority       = [Priority]       
              , @dt_OrderDate     = OrderDate      
              , @dt_Delivery_Date = DeliveryDate  
              , @c_OrderType      = [Type]      
              , @c_Door           = Door           
              , @c_Route          = [Route]          
              , @c_DeliveryPlace  = DeliveryPlace      
              , @c_ExternOrderKey = ExternOrderKey 
              , @c_CustomerName   = C_Company   
              , @c_Status         = [Status]
         FROM ORDERS (NOLOCK)
         WHERE OrderKey = @c_GetOrderkey

         EXEC isp_InsertLoadplanDetail
            @cLoadKey        = @c_GetLoadkey
          , @cFacility       = @c_Facility
          , @cOrderKey       = @c_GetOrderkey
          , @cConsigneeKey   = @c_ConsigneeKey
          , @cPrioriry       = @c_Priority
          , @dOrderDate      = @dt_OrderDate
          , @dDelivery_Date  = @dt_Delivery_Date
          , @cOrderType      = @c_OrderType
          , @cDoor           = @c_Door
          , @cRoute          = @c_Route
          , @cDeliveryPlace  = @c_DeliveryPlace
          , @nStdGrossWgt    = @n_totweight
          , @nStdCube        = @n_totcube
          , @cExternOrderKey = @c_ExternOrderKey
          , @cCustomerName   = @c_CustomerName
          , @nTotOrderLines  = @n_TotLines
          , @nNoOfCartons    = '1'
          , @cOrderStatus    = @c_Status
          , @b_Success       = @b_Success
          , @n_Err           = @n_Err
          , @c_ErrMsg        = @c_ErrMsg

         IF @n_Err <> 0
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Inserting LoadplanDetail'
         
            GOTO NEXT_LOOP
         END

         SET @c_Status = '0'    
         SELECT @c_Status =   CASE
                              WHEN MAX(LPD.Status) = '0' THEN '0'
                              WHEN MIN(LPD.Status) = '0' and MAX(Status) >= '1' THEN '1'
                              ELSE MIN(LPD.Status)
                              END
         FROM  LOADPLANDETAIL LPD WITH (NOLOCK)
         WHERE LPD.Loadkey = @c_GetLoadkey

         UPDATE LoadPlan WITH (ROWLOCK)                                                                                                                           
         SET [Status]   = @c_Status,                                                                  
             Trafficcop = NULL, 
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME()                                                                                                                                    
         WHERE LoadKey = @c_GetLoadkey  

         IF @n_Err <> 0
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Updating Loadplan'
         
            GOTO NEXT_LOOP
         END
      END

      --Waving
      IF @n_Continue IN (1,2)
      BEGIN
         --Generate Wavekey
         SELECT @b_success = 0  
         SET @c_Wavekey = ''
         EXECUTE nspg_GetKey  
                  'Wavekey',  
                  10,  
                  @c_Wavekey   OUTPUT,  
                  @b_success   OUTPUT,  
                  @n_err       OUTPUT,  
                  @c_errmsg    OUTPUT  

         IF @b_Success = 0
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error getting Wavekey'
         
            GOTO NEXT_LOOP
         END
         ELSE
         BEGIN
            INSERT INTO dbo.WAVE (WaveKey, WaveType, DispatchPalletPickMethod, DispatchCasePickMethod
                                , DispatchPiecePickMethod, [Status], TMReleaseFlag)
            VALUES (@c_Wavekey
                  , N'0'
                  , N'1'
                  , N'1'
                  , N'1'
                  , N'0'
                  , N'N'
               )

            SELECT @n_err = @@ERROR 
            
            IF @n_err <> 0
            BEGIN 
               INSERT INTO #TMP_RESULT (Orderkey, Reason)
               SELECT @c_GetOrderkey, 'Error inserting Wave'
            
               GOTO NEXT_LOOP
            END
            ELSE
            BEGIN
               SELECT @b_success = 0  
               SELECT @c_Wavedetailkey = ''  
               EXECUTE nspg_GetKey  
                  'WavedetailKey',  
                  10,  
                  @c_WaveDetailKey  OUTPUT,  
                  @b_success     OUTPUT,  
                  @n_err         OUTPUT,  
                  @c_errmsg      OUTPUT  
                    
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
               END             
               ELSE   
               BEGIN                                     
                  INSERT INTO WAVEDETAIL ( Wavedetailkey, Wavekey, Orderkey )  
                  VALUES ( @c_Wavedetailkey, @c_Wavekey, @c_GetOrderkey)  
               
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     INSERT INTO #TMP_RESULT (Orderkey, Reason)
                     SELECT @c_GetOrderkey, 'Error inserting WaveDetail'
                     
                     GOTO NEXT_LOOP
                  END
               END
            END
         END
      END

      --Packing
      IF @n_Continue IN (1,2)
      BEGIN
         --Generate Discrete Pickslip
         EXEC isp_CreatePickSlip
                 @c_Orderkey           = @c_GetOrderkey
               , @c_LinkPickSlipToPick = 'Y'
               , @c_ConsolidateByLoad  = 'N'
               , @c_AutoScanIn         = 'Y'
               , @c_Refkeylookup       = 'N'
               , @c_PickslipType       = '3'
               , @b_Success            = @b_Success OUTPUT
               , @n_Err                = @n_err OUTPUT 
               , @c_ErrMsg             = @c_errmsg OUTPUT       	
            
         IF @b_Success = 0
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error executing isp_CreatePickSlip'
         
            GOTO NEXT_LOOP
         END

         SELECT @c_GetPickslipno = PH.Pickheaderkey
         FROM PICKHEADER PH (NOLOCK)
         WHERE PH.OrderKey = @c_GetOrderkey
         AND PH.[Zone] = '3'

         IF ISNULL(@c_GetPickslipno, '') <> '' AND NOT EXISTS (SELECT 1 FROM PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @c_GetPickslipno)     
         BEGIN
            INSERT INTO PackHeader ([Route], OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
            SELECT OH.[Route], OH.OrderKey, SUBSTRING(OH.ExternOrderKey, 1, 18), OH.LoadKey, OH.ConsigneeKey, OH.Storerkey, @c_GetPickslipno       
            FROM PICKHEADER PH WITH (NOLOCK)      
            JOIN ORDERS OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)      
            WHERE PH.PickHeaderKey = @c_GetPickslipno  
         END

         EXEC isp_GenUCCLabelNo_Std @cPickslipNo = @c_GetPickslipno
                                  , @nCartonNo   = 1
                                  , @cLabelNo    = @c_GetLabelNo OUTPUT
                                  , @b_success   = @b_success    OUTPUT
                                  , @n_err       = @n_err        OUTPUT
                                  , @c_errmsg    = @c_errmsg     OUTPUT

         IF @b_Success = 0
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error executing isp_GenUCCLabelNo_Std'
         
            GOTO NEXT_LOOP
         END

         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT SKU, SUM(QTY)  
         FROM   PICKDETAIL WITH (NOLOCK)  
         WHERE  OrderKey = @c_GetOrderkey   
         AND    Qty > 0   
         GROUP BY SKU  
           
         OPEN CUR_PICKDETAIL  
           
         FETCH NEXT FROM CUR_PICKDETAIL INTO @c_GetSKU, @n_GetQty   
         WHILE @@FETCH_STATUS<>-1  
         BEGIN  
            -- Create packdetail    
            IF NOT EXISTS(SELECT 1 FROM PackDetail PD WITH (NOLOCK)   
                          WHERE PD.PickSlipNo = @c_GetPickslipno   
                          AND   PD.StorerKey = @c_StorerKey    
                          AND   PD.sku = @c_GetSKU)  
            BEGIN   
               SET @n_LabelLineCNT = @n_LabelLineCNT + 1

               INSERT INTO PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)    
               SELECT @c_GetPickslipno, 1, @c_GetLabelNo, RIGHT('00000' + CAST(@n_LabelLineCNT AS NVARCHAR(5)), 5), @c_StorerKey, @c_GetSKU,   
                      @n_GetQty, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE()   

               IF @@ERROR <> 0
               BEGIN 
                  INSERT INTO #TMP_RESULT (Orderkey, Reason)
                  SELECT @c_GetOrderkey, 'Generate Packdetail Failed'
               
                  GOTO NEXT_LOOP
               END
         
            END  
            FETCH NEXT FROM CUR_PICKDETAIL INTO @c_GetSKU, @n_GetQty  
         END  
         CLOSE CUR_PICKDETAIL  
         DEALLOCATE CUR_PICKDETAIL  

         --AssignPackLabelToOrdCfg
         EXEC dbo.nspGetRight @c_Facility = @c_Facility
                            , @c_StorerKey = @c_Storerkey
                            , @c_sku = NULL
                            , @c_ConfigKey = N'AssignPackLabelToOrdCfg'
                            , @b_Success = @b_Success OUTPUT
                            , @c_authority = @c_Authority OUTPUT
                            , @n_err = @n_err OUTPUT
                            , @c_errmsg = @c_errmsg OUTPUT
                            , @c_Option2 = @c_Option2 OUTPUT
         
         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'EXEC nspGetRight Failed'
         END

         IF @c_Authority = '1'
         BEGIN
            EXEC dbo.isp_AssignPackLabelToOrderByLoad @c_Pickslipno = @c_GetPickslipno
                                                    , @b_Success = @b_Success OUTPUT
                                                    , @n_err = @n_err OUTPUT
                                                    , @c_errmsg = @c_errmsg OUTPUT
         
            IF @n_err <> 0
            BEGIN
               INSERT INTO #TMP_RESULT (Orderkey, Reason)
               SELECT @c_GetOrderkey, 'EXEC isp_AssignPackLabelToOrderByLoad Failed'
            END
         END

         --Pack Confirm
         UPDATE PACKHEADER
         SET [Status] = '9'
         WHERE PickSlipNo =  @c_GetPickslipno

         IF @@ERROR <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Pack Confirm Failed'
         END

         --Scan Out Pickslip
         EXEC isp_ScanOutPickSlip  
               @c_PickSlipNo  = @c_GetPickslipno
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg    OUTPUT
         
         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Scan Out Failed'
         END
      END

      --Create MBOL
      IF @n_Continue IN (1,2)
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
                'MBOL',
                10,
                @c_GetMBOLKey OUTPUT,
                @b_success    OUTPUT,
                @n_err        OUTPUT,
                @c_errmsg     OUTPUT
         
         IF @b_success <> 1
         BEGIN 
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Getting MBOLKey'
         
            GOTO NEXT_LOOP
         END

         SELECT @dt_OrderDate     = OH.OrderDate,
                @dt_Delivery_Date = OH.DeliveryDate,
                @c_Route          = OH.[Route],
                @n_totweight      = SUM((OD.Qtyallocated + OD.QtyPicked + OD.ShippedQty) * SKU.StdGrossWgt),
                @n_totcube        = SUM((OD.Qtyallocated + OD.QtyPicked + OD.ShippedQty) * SKU.StdCube),
                @c_ExternOrderkey = OH.ExternOrderkey,
                @c_Loadkey        = ISNULL(OH.Loadkey,''),
                @c_Facility       = OH.Facility
         FROM ORDERS OH (NOLOCK)
         JOIN Orderdetail OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
         JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)
         WHERE OH.OrderKey = @c_GetOrderkey
         GROUP BY OH.OrderDate,
                  OH.DeliveryDate,
                  OH.[Route],
                  OH.ExternOrderkey,
                  ISNULL(OH.Loadkey,''),
                  OH.Facility

         INSERT INTO MBOL (MBOLKey, Facility, PlaceOfdeliveryQualifier, TransMethod, Userdefine09, Userdefine02, Userdefine04) 
         VALUES (@c_GetMBOLKey, @c_Facility, 'D','O', '', 'Y', 'Y')

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Generate MBOL Failed'
            
            GOTO NEXT_LOOP
         END


         IF NOT EXISTS (SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE Orderkey = @c_GetOrderkey)
         BEGIN 
            EXEC isp_InsertMBOLDetail
                  @cMBOLKey        = @c_GetMBOLKey,
                  @cFacility       = @c_Facility,
                  @cOrderKey       = @c_GetOrderkey,
                  @cLoadKey        = @c_Loadkey,
                  @nStdGrossWgt    = @n_totweight,
                  @nStdCube        = @n_totcube,
                  @cExternOrderKey = @c_ExternOrderkey,
                  @dOrderDate      = @dt_OrderDate,
                  @dDelivery_Date  = @dt_Delivery_Date,
                  @cRoute          = @c_Route,
                  @b_Success       = @b_Success OUTPUT,
                  @n_err           = @n_err     OUTPUT,
                  @c_errmsg        = @c_errmsg  OUTPUT
            
            IF @n_err <> 0
            BEGIN
               INSERT INTO #TMP_RESULT (Orderkey, Reason)
               SELECT @c_GetOrderkey, 'Error Executing isp_InsertMBOLDetail'
               
               GOTO NEXT_LOOP
            END
         END

         UPDATE MBOL
         SET DepartureDate = GETDATE()
           , TrafficCop    = NULL
         WHERE MbolKey = @c_GetMBOLKey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Update MBOL Failed'
            
            GOTO NEXT_LOOP
         END
      END

      --Validate MBOL
      IF @n_Continue IN (1,2)
      BEGIN
         EXEC [dbo].[isp_ValidateMBOL]
            @c_MBOLKey    = @c_GetMBOLKey
          , @b_ReturnCode = @b_ReturnCode OUTPUT -- 0 = OK, -1 = Error, 1 = Warning
          , @n_err        = @n_err        OUTPUT
          , @c_errmsg     = @c_errmsg     OUTPUT
          , @n_CBOLKey    = 0
          , @c_CallFrom   = ''

         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Executing isp_ValidateMBOL'
            
            GOTO NEXT_LOOP
         END

         IF @b_ReturnCode = -1
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Validate MBOL Failed'
            
            GOTO NEXT_LOOP
         END
      END

      --Ship MBOL
      IF @n_Continue IN (1,2)
      BEGIN
         EXEC [dbo].[isp_ShipMBOL]
            @c_MBOLKey    = @c_GetMBOLKey
          , @b_Success    = @b_Success    OUTPUT
          , @n_err        = @n_err        OUTPUT
          , @c_errmsg     = @c_errmsg     OUTPUT

         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Executing isp_ShipMBOL'
            
            GOTO NEXT_LOOP
         END

         UPDATE MBOL 
         SET Status = '9'
         WHERE MbolKey = @c_GetMBOLKey

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            INSERT INTO #TMP_RESULT (Orderkey, Reason)
            SELECT @c_GetOrderkey, 'Error Updating MBOL.Status = 9'
            
            GOTO NEXT_LOOP
         END
      END

      INSERT INTO #TMP_RESULT (Orderkey, Reason)
      SELECT @c_GetOrderkey, 'Processed Successfully'

NEXT_LOOP:
      FETCH NEXT FROM CUR_LOOP INTO @c_GetOrderkey
   END   --End Orders Loop
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   --SELECT * FROM #TMP_RESULT      
QUIT_SP:
   --Send alert by email
   IF EXISTS (SELECT 1 FROM #TMP_RESULT)
   BEGIN   	  
      SET @c_SendEmail = 'Y'                                                       
      SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
      SET @c_Subject = TRIM(@c_Storerkey) + ' Auto Wave Pack Ship Alert - ' + @c_Date  
      
      SET @c_Body = '<style type="text/css">       
               p.a1  {  font-family: Arial; font-size: 12px;  }      
               table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
               table, td, th {padding:3px; font-size: 12px; }
               td { vertical-align: top}
               </style>'
   
      SET @c_Body = @c_Body + '<p>Dear All, </p>'  
      SET @c_Body = @c_Body + '<p>Please be informed that the Orderkey below has been processed.</p>'  
      SET @c_Body = @c_Body + '<p>Kindly refer to the Remark for more info.</p>'  + CHAR(13)
         
      SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
      SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Orderkey</th><th>Remark</th></tr>'  
      
      DECLARE CUR_EMAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
         SELECT T.Orderkey, T.Reason    
         FROM #TMP_RESULT T
         ORDER BY T.Orderkey
        
      OPEN CUR_EMAIL              
        
      FETCH NEXT FROM CUR_EMAIL INTO @c_GetOrderkey, @c_GetReason   
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN  
         SET @c_Body = @c_Body + '<tr><td>' + RTRIM(@c_GetOrderkey) + '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_GetReason) + '</td>'  
         SET @c_Body = @c_Body + '</tr>'  

         IF @c_GetReason <> 'Processed Successfully'
         BEGIN
            UPDATE ORDERS
            SET Notes      = 'HOLD',
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE OrderKey = @c_GetOrderkey
         END
                                            
         FETCH NEXT FROM CUR_EMAIL INTO @c_GetOrderkey, @c_GetReason        
      END  
      CLOSE CUR_EMAIL              
      DEALLOCATE CUR_EMAIL           
      
      SET @c_Body = @c_Body + '</table>'  

      IF @b_debug = 1
      BEGIN 
         PRINT @c_Subject
         PRINT @c_Body
      END

      IF @c_SendEmail = 'Y' AND ISNULL(@c_Recipients,'') <> ''
      BEGIN           
         EXEC msdb.dbo.sp_send_dbmail   
               @recipients      = @c_Recipients,  
               @copy_recipients = NULL,  
               @subject         = @c_Subject,  
               @body            = @c_Body,  
               @body_format     = 'HTML' ;  
                 
         SET @n_Err = @@ERROR  
         
         IF @n_Err <> 0  
         BEGIN           
            UPDATE ORDERS WITH (ROWLOCK)
            SET Notes      = 'EMAIL FAILED',
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE OrderKey = @c_GetOrderkey                          
         END  
      END
   END

   IF OBJECT_ID('tempdb..#TMP_Orders') IS NOT NULL
            DROP TABLE #TMP_Orders

   IF OBJECT_ID('tempdb..#TMP_RESULT') IS NOT NULL
            DROP TABLE #TMP_RESULT

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PICKDETAIL') IN (0 , 1)
   BEGIN
      CLOSE CUR_PICKDETAIL
      DEALLOCATE CUR_PICKDETAIL   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_EMAIL') IN (0 , 1)
   BEGIN
      CLOSE CUR_EMAIL
      DEALLOCATE CUR_EMAIL   
   END
           
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_MAST_AutoWavePackShip'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO