SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: isp_Ecom_QueryRules                                            */
/* Creation Date: 19-APR-2016                                              */
/* Copyright: LF Logistics                                                 */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#361901 - New ECOM Packing                                  */
/*        : 1) Basic Check Input By Task ID                                */
/*        : 2) Basic Check Input By Shipment Orders                        */
/*        : 3) Basic Check Input By Task ID & Shipment Orders              */
/*        : 4) Check to allow change orderkey                              */
/*        :    a) Retrieve the input/selected orderkey                     */
/*        :    b) Swap Pack Header orderkey                                */
/* Called By: nep_n_cst_visual_pack_ecom                                   */
/*          : Function of_QueryRules                                       */
/* PVCS Version: 2.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver Purposes                                     */
/* 21-SEP-2016 Wan01    1.1   Performance Tune                             */
/* 20-OCT-2016 Wan02    1.2   Fixed                                        */
/* 31-OCT-2016 Wan03    1.3   Fixed                                        */
/* 04-AUG-2017 Wan04    1.4   WMS-2306 - CN-Nike SDC WMS ECOM Packing CR   */
/* 06-OCT-2017 Wan05    1.5   Performance Tune                             */
/* 01-NOV-2017 Wan06    1.6   Fixed. Try to Set orderkey if from           */
/*                            orderkey is empty                            */
/* 02-NOV-2017 Wan07    1.7   Fixed. Initial @n_Continue = 1 else          */
/*                            Original orderkey not reset in packtaskdetail*/
/* 01-AUG-2018 Wan08    1.8   WMS-4971 - [CN] UA Relocation Phase II -     */
/*                            Exceed ECOM Packing                          */
/* 14-AUG-2018 Wan09    1.9   WMS-4971 - [CN] UA Relocation Phase II -     */
/*                            Exceed ECOM Packing                          */
/* 24-AUG-2018 Wan10    1.10  Performance tune                             */
/* 23-MAY-2019 Wan11    1.10  Fixed. Allow to change Orderkey if           */
/*                            to orderkey has not started packing          */
/* 04-Feb-2020 NJOW01   1.11  WMS-11766 allow super user/computer take     */
/*                            over partial packing of other user/computer  */
/* 04-MAR-2021 Wan12    2.0   WMS-16390 - [CN] NIKE_O2_Ecompacking_Check   */
/*                            _Pickdetail_status_CR                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_Ecom_QueryRules] 
            @c_TaskID         NVARCHAR(10)   OUTPUT   --(Wan08)
         ,  @c_PickSlipNo     NVARCHAR(10)
         ,  @c_Orderkey       NVARCHAR(10)   OUTPUT   --(Wan08)
         ,  @c_UserID         NVARCHAR(30)
         ,  @c_ComputerName   NVARCHAR(30)
         ,  @b_Success        INT            OUTPUT -- -1:Fail, 0:No Work, 1:Perform Search/addnew, 2:Set Orderkey
         ,  @c_ErrMsg         NVARCHAR(255)  OUTPUT
         ,  @c_DropID         NVARCHAR(20)   = '' 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_TaskBatchNo        NVARCHAR(10)

         , @c_FromOrderkey       NVARCHAR(10) 
         , @c_FromPackStatus     NVARCHAR(10)
         , @c_PackStatus         NVARCHAR(10) 
         , @c_SOStatus           NVARCHAR(10)

         --, @b_Success            INT
         , @n_err                INT             
         --, @c_errmsg             NVARCHAR(250) 

         , @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_ConfigKey          NVARCHAR(30)
         , @c_authority          NVARCHAR(30) 
         , @c_Option1            NVARCHAR(50)   
         , @c_Option2            NVARCHAR(50)  
         , @c_Option3            NVARCHAR(50)
         , @c_Option4            NVARCHAR(50) 
         , @c_Option5            NVARCHAR(4000)
         , @c_EPACKForceMultiPackByOrd NVARCHAR(30) --(Wan04)

         , @n_RowRef          BIGINT            --(Wan01)
         , @c_PTD_Orderkey    NVARCHAR(10)      --(Wan01)
         , @c_PTD_PickSlipNo  NVARCHAR(10)      --(Wan01)
         , @c_PTD_Status      NVARCHAR(10)      --(Wan01)
         , @c_PTD_ToStatus    NVARCHAR(10)      --(Wan01)
         , @b_UpdPTD          INT               --(Wan01) 

         , @c_OrderMode       NVARCHAR(10)      --(Wan01)
         , @n_NoOfTaskID      INT               --(Wan08)
         , @n_DropID_WIP      INT               --(Wan08)
         , @n_NoOfOrders      INT               --(Wan08)

   DECLARE @n_Reccnt          INT               --(Wan10)
         , @c_PackUserID      NVARCHAR(30)      --(Wan10)
         , @c_PackStationName NVARCHAR(30)      --(Wan10)

         , @c_OrderID         NVARCHAR(10)      --(Wan10)
         
   --NJOW01         
   DECLARE @c_EPACKTAKEOVER   NVARCHAR(30)
         , @c_OptionTO1       NVARCHAR(50)   
         , @c_OptionTO2       NVARCHAR(50)  
         , @c_OptionTO3       NVARCHAR(50)
         , @c_OptionTO4       NVARCHAR(50) 
         , @c_OptionTO5       NVARCHAR(4000)
           
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1                         --(Wan07)
   SET @b_Success = 2

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   --(Wan01) - START
   IF @c_TaskID     IS NULL BEGIN SET @c_TaskID   = '' END
   IF @c_Orderkey   IS NULL BEGIN SET @c_Orderkey = '' END
   IF @c_PickSlipNo IS NULL BEGIN SET @c_PickSlipNo = '' END

   IF @c_TaskID = '' AND @c_Orderkey = '' AND @c_DropID = ''
   BEGIN
      SET @b_Success = 0
      GOTO QUIT_SP
   END

   --(Wan08) - START
   IF @c_DropID <> '' -- Input DropID only  
   BEGIN
      SET @n_NoOfTaskID = 0
      SET @n_DropID_WIP = 0
      SELECT @n_NoOfTaskID = COUNT(DISTINCT PT.TaskBatchNo)
            ,@n_DropID_WIP = COUNT(1)
            ,@n_NoOfOrders = COUNT(DISTINCT PD.Orderkey)
            ,@c_TaskID     = MAX(PT.TaskBatchNo)
            ,@c_Orderkey   = MAX(PT.Orderkey)
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN PACKTASK   PT WITH (NOLOCK) ON (PD.Orderkey = PT.Orderkey)
      WHERE PD.DropID = @c_DropID
      AND PD.Status < '5'
      AND PD.ShipFlag NOT IN ('P', 'Y')
         
      IF @n_DropID_WIP = 0
      BEGIN
         SET @b_Success = -1
         SET @n_Err    = 60036
         SET @c_ErrMsg = 'Invalid E-Pack DropID : ' + RTRIM(@c_DropID) + '. DropID Not Found or had been Packed/Shipped.' 
         GOTO QUIT_SP
      END

      IF @n_NoOfTaskID = 0
      BEGIN
         SET @b_Success = -1
         SET @n_Err    = 60036
         SET @c_ErrMsg = 'Invalid E-Pack DropID : Task # for Carton #: ' + RTRIM(@c_DropID) + ' Not Found!.' 
         GOTO QUIT_SP
      END    

      IF @n_NoOfTaskID > 1 
      BEGIN            
         SET @b_Success = -1
         SET @n_Err    = 60037
         SET @c_ErrMsg = 'Invalid E-Pack DropID : ' + RTRIM(@c_DropID) + '. Multiple TaskID Found.' 
         GOTO QUIT_SP
      END

      SET @n_NoOfOrders = 0
      SET @c_OrderMode  = ''                                      --(Wan09)
      SELECT @n_NoOfOrders = COUNT(DISTINCT PD.Orderkey)
            ,@c_OrderMode  = ISNULL(MIN(PT.OrderMode),'')         --(Wan09)
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN PACKTASK   PT WITH (NOLOCK) ON (PD.Orderkey = PT.Orderkey)
      WHERE PT.TaskBatchNo = @c_TaskID 
      AND   PD.DropID = @c_DropID

      IF @n_NoOfOrders = 1 AND LEFT(@c_OrderMode,1) = 'M' -- 1 Orderkey 1 DropId, Pack By Orderkey --(Wan09)   
      BEGIN
         SET @c_TaskID = ''
      END
      ELSE-- Multi Orderkey in 1 DropId OR Single Order Mode, Pack bY Task ID
      BEGIN
         SET @c_Orderkey = ''
      END

      SET @c_OrderMode  = ''                                      --(Wan09)
   END
   --(Wan08) - END

   SET @c_TaskBatchNo = ''
   SET @c_Facility   = ''
   SET @c_Storerkey  = ''
   SET @c_SOStatus = ''

   --(Wan10) - START
   IF ISNULL(RTRIM(@c_Orderkey),'') <> ''
   BEGIN
      SELECT TOP 1 
             @c_TaskBatchNo = PACKTASK.TaskBatchNo
            ,@c_OrderMode = PACKTASK.OrderMode
            ,@c_OrderID   = PACKTASK.Orderkey
      FROM PACKTASK WITH (NOLOCK) 
      WHERE PACKTASK.Orderkey = @c_Orderkey 
   END
   ELSE
   BEGIN
      SELECT TOP 1 
             @c_TaskBatchNo = PACKTASK.TaskBatchNo
            ,@c_OrderMode = PACKTASK.OrderMode
            ,@c_OrderID   = PACKTASK.Orderkey
      FROM PACKTASK WITH (NOLOCK) 
      WHERE PACKTASK.TaskBatchNo = @c_TaskID 
   END
   
   IF @c_TaskBatchNo = ''   -- Task Batch # Not Found
   BEGIN
      SET @b_Success = -1
      SET @n_Err    = 60010
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Task Batch #: ' + RTRIM(@c_TaskID) + ' Not found.'
      GOTO QUIT_SP
   END

   --(Wan11) - Fixed Input/Scan Orderkey not belong to TaskID - START
   IF @c_TaskBatchNo <> @c_TaskID AND @c_TaskID <> '' 
   BEGIN
      SET @b_Success = -1
      SET @n_Err    = 60012
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Invalid Order #:' +  @c_Orderkey + ' for Task Batch #: ' + RTRIM(@c_TaskID) 
      GOTO QUIT_SP
   END
   --(Wan11) - Fixed Input/Scan Orderkey not belong to TaskID - END   

   SELECT @c_Facility  = ORDERS.Facility
         ,@c_Storerkey = ORDERS.Storerkey
         ,@c_SOStatus  = ORDERS.SOStatus
   FROM ORDERS   WITH (NOLOCK) 
   WHERE  ORDERS.Orderkey = @c_OrderID
   --(Wan10) - END
   
   
   --NJOW01 S
   SET @c_ConfigKey = 'EPACKTAKEOVER'
   SET @b_Success = 1
   SET @n_err     = 0

   EXEC nspGetRight  
         @c_Facility           
      ,  @c_StorerKey             
      ,  ''       
      ,  @c_ConfigKey             
      ,  @b_Success       OUTPUT   
      ,  @c_EPACKTAKEOVER OUTPUT  
      ,  @n_err           OUTPUT  
      ,  @c_errmsg        OUTPUT
      ,  @c_OptionTO1     OUTPUT 
      ,  @c_OptionTO2     OUTPUT
      ,  @c_OptionTO3     OUTPUT
      ,  @c_OptionTO4     OUTPUT
      ,  @c_OptionTO5     OUTPUT

   IF @b_Success <> 1 
   BEGIN 
      SET @b_Success = -1
      SET @n_Err     = 60019
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Error Executing nspGetRight. '
      GOTO QUIT_SP
   END
   --NJOW01 E

   --(Wan10) - START
   IF ISNULL(RTRIM(@c_Orderkey),'') <> ''
   BEGIN
      SET @c_ConfigKey = 'MultiPackMode'
      SET @b_Success = 1
      SET @n_err     = 0
      SET @c_errmsg  = ''
      SET @c_Option1 = ''
      SET @c_Option2 = ''
      SET @c_Option3 = ''
      SET @c_Option4 = ''
      SET @c_Option5 = ''

      EXEC nspGetRight  
            @c_Facility           
         ,  @c_StorerKey             
         ,  ''       
         ,  @c_ConfigKey             
         ,  @b_Success    OUTPUT   
         ,  @c_authority  OUTPUT  
         ,  @n_err        OUTPUT  
         ,  @c_errmsg     OUTPUT
         ,  @c_Option1    OUTPUT 
         ,  @c_Option2    OUTPUT
         ,  @c_Option3    OUTPUT
         ,  @c_Option4    OUTPUT
         ,  @c_Option5    OUTPUT

      IF @b_Success <> 1 
      BEGIN 
         SET @b_Success = -1
         SET @n_Err     = 60020
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Error Executing nspGetRight. '
         GOTO QUIT_SP
      END

      IF @c_Option1 <> ''
      BEGIN
         SET @n_Reccnt = 0
         SET @c_PackUserID = ''
         SET @c_PackStationName = ''

         SELECT @n_Reccnt = 1
               ,@c_PackUserID = PACKHEADER.AddWho 
               ,@c_PackStationName = PACKHEADER.ComputerName
         FROM PACKHEADER WITH (NOLOCK) 
         WHERE PACKHEADER.Orderkey = @c_Orderkey 

         IF @n_Reccnt > 0
         BEGIN                           
            IF @c_Option1 = 'userid' AND @c_UserID <> @c_PackUserID AND NOT (@c_EPACKTAKEOVER = '1' AND @c_OptionTO1 = 'USERID' AND CHARINDEX(@c_UserId, @c_OptionTO5) > 0)  --NJOW01
               SET @n_Reccnt = 0 
            IF @c_Option1 = 'computer' AND @c_ComputerName <> @c_PackStationName  AND NOT (@c_EPACKTAKEOVER = '1' AND @c_OptionTO1 = 'COMPUTER' AND CHARINDEX(@c_ComputerName, @c_OptionTO5) > 0)  --NJOW01
               SET @n_Reccnt = 0 

            IF @n_Reccnt = 0
            BEGIN
               SET @b_Success = -1
               SET @n_Err    = 60030
               SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Pack Task record ' 
                             + CASE WHEN @c_Option1 = 'userid' THEN ' for User ID: ' + RTRIM(@c_UserID)
                                    WHEN @c_Option1 = 'computer' THEN ' for Pack Station: ' + RTRIM(@c_ComputerName)
                                    ELSE ''
                                    END
                             + ' Not found.'
               GOTO QUIT_SP
            END
         END
      END
   END
   --(Wan10) - END

   IF @c_Orderkey = '' -- Input Task # only  
   BEGIN
      --Search & Add New if Not found
      SET @b_Success = 1
      GOTO QUIT_SP
   END
 
   -- Check Search Shipment Order or Changing Shipment OrderKey
   IF @c_SOStatus IN ('CANC', 'HOLD') OR
      EXISTS (SELECT 1
              FROM CODELKUP WITH (NOLOCK) 
              WHERE ListName = 'NONEPACKSO'
              AND   Code = @c_SOStatus       -- = 'CANC'
              AND ((Storerkey = '') OR Storerkey = @c_Storerkey)
              ) 
   BEGIN
      SET @b_Success = -1
      SET @n_Err    = 60040
      SET @c_ErrMsg = 'Invalid E-Pack Shipment Order: ' + RTRIM(@c_Orderkey)+ '''s SOStatus: ' + RTRIM(@c_SOStatus) 
      GOTO QUIT_SP
   END

   --(Wan02 & Wan05) = START
   SET @c_PTD_PickSlipNo = '' 
   SET @c_PTD_ToStatus   = '' 
   SET @c_PTD_ToStatus = dbo.fnc_ECOM_GetPackOrderStatus (@c_TaskBatchNo, @c_PickSlipNo, @c_Orderkey)  
   
   --(Wan12) - START
   IF @c_PTD_ToStatus = '0' 
   BEGIN
      SELECT TOP 1 @c_PTD_ToStatus = PTD.[Status]            
      FROM PACKTASKDETAIL PTD WITH (NOLOCK)   
      WHERE PTD.TaskBatchNo = @c_TaskBatchNo
      AND PTD.Orderkey = @c_Orderkey
      AND PTD.[Status] = 'P'
      
      IF @c_PTD_ToStatus = 'P'
      BEGIN
         -- Not Allow to retrieve/change if Order is pending in Progress 
         SET @b_Success = -1
         SET @n_Err    = 60042
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Pack By Shipment Order Error. Order is pending in progress.'
         GOTO QUIT_SP
      END
   END
   --(Wan12) - END          
     
   IF @c_PTD_ToStatus = '9' --AND @c_PTD_PickSlipNo = ''    
   BEGIN
      SELECT TOP 1 @c_PTD_PickSlipNo = PickSlipNo            
      FROM PACKTASKDETAIL WITH (NOLOCK)   
      WHERE TaskBatchNo = @c_TaskBatchNo
      AND Orderkey = @c_Orderkey

      IF @c_PTD_PickSlipNo = ''                             
      BEGIN
         -- Not Allow to retrieve/change if Order is picked/shipped without ECOM Packing  
         SET @b_Success = -1
         SET @n_Err    = 60041
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Pack By Shipment Order Error. Order is picked/shipped without ECOM Packing.'
         GOTO QUIT_SP
      END
   END
   --(Wan02 & Wan05) = END
   
   IF LEFT(@c_OrderMode,1) = 'S'
   BEGIN
      --(Wan04) - START --Allow to search Single Mode Order for re-print
      IF @c_PTD_ToStatus IN ('3','9')
      BEGIN
         SET @b_Success = 1
         GOTO QUIT_SP
      END
      --(Wan04) - END

      SET @b_Success = -1
      SET @n_Err    = 60050
      SET @c_ErrMsg = 'Not allow to pack single mode task batch by Shipment Order: ' + RTRIM(@c_Orderkey) 

      GOTO QUIT_SP
   END
   -- 1) PickSlipNo = '' -- New/NewModified Mode where by sku has not scanned yet or First time retrieve by Taskid/Shipment Order
   -- 2) PickSlipNo > '' -- NotModified/dataModified Mode


   IF @c_PickSlipNo = '' -- New Mode if input by shipment orders
   BEGIN
      --Search & Add New if Not found
      SET @b_Success = 1
      GOTO QUIT_SP
   END

   SET @c_FromOrderkey = ''
   SET @c_FromPackStatus = ''
   SELECT @c_FromOrderkey  = Orderkey
         ,@c_FromPackStatus= Status
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND   TaskBatchNo= @c_TaskBatchNo

   IF @c_FromOrderkey = @c_Orderkey 
   BEGIN
      -- If Both not blank and same Value, not to change / retrieve
      SET @b_Success = 0
      GOTO QUIT_SP
   END

   --(Wan06) - START (Not to Search if from orderkey is blank. Need to set orderkey)
   --IF @c_FromOrderkey = ''  
   --BEGIN
   --   SET @b_Success = 1
   --   GOTO QUIT_SP
   --END
   --(Wan06) - END

   --(Wan04) - START
   SET @c_ConfigKey = 'EPACKForceMultiPackByOrd'
   SET @b_Success = 1
   SET @n_err     = 0
   SET @c_errmsg  = ''
   SET @c_Option1 = ''
   SET @c_Option2 = ''
   SET @c_Option3 = ''
   SET @c_Option4 = ''
   SET @c_Option5 = ''

   EXEC nspGetRight  
         @c_Facility           
      ,  @c_StorerKey             
      ,  ''       
      ,  @c_ConfigKey             
      ,  @b_Success                    OUTPUT   
      ,  @c_EPACKForceMultiPackByOrd   OUTPUT  
      ,  @n_err                        OUTPUT  
      ,  @c_errmsg                     OUTPUT
      ,  @c_Option1                    OUTPUT 
      ,  @c_Option2                    OUTPUT
      ,  @c_Option3                    OUTPUT
      ,  @c_Option4                    OUTPUT
      ,  @c_Option5                    OUTPUT

   IF @c_EPACKForceMultiPackByOrd = 1
   BEGIN 
      SET @b_Success = 1
      GOTO QUIT_SP
   END
   --(Wan04) - END

   /*------------------------------------------------------*/
   /***** Check if to allow Retrieve / change orderkey *****/
   /*------------------------------------------------------*/
   /*------------------------------------------------------*/
   /*   Packed By Shipment Orderkey                        */
   /*   - Input Shipment Orderkey to start Pack            */
   /*------------------------------------------------------*/
   SET @b_Success = 0


   -- (Wan11) - START
   IF EXISTS ( SELECT 1
               FROM PACKHEADER WITH (NOLOCK)
               WHERE Orderkey = @c_Orderkey
             )
   BEGIN
      -- Allow to retrieve if In progress/packed confirm order if the change orderkey has started packing
      SET @b_Success = 1
      GOTO QUIT_SP
   END
   -- (Wan11) - END

   IF @c_TaskID = ''
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM PACKHEADER WITH (NOLOCK)
                  WHERE TaskBatchNo = @c_TaskBatchNo
                  AND   Orderkey = ''
                )
      BEGIN
         SET @b_Success = -1
         SET @n_Err    = 60060
         SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Pack By Shipment Order Error. Pending packing by task found.'
     
         GOTO QUIT_SP 
      END  

      IF @c_PTD_ToStatus IN ('3', '9')
      BEGIN
         -- Allow to retrieve if In progress/packed confirm order   
         SET @b_Success = 1
         GOTO QUIT_SP
      END 

      IF @c_PTD_ToStatus IN ('1', '2')
      BEGIN
         -- Allow to Change Orderkey 
         SET @b_Success = 2        
         GOTO QUIT_SP
      END
    
      IF @c_PTD_ToStatus = '0' 
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM PACKDETAIL WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo
                        )
         BEGIN
            -- Allow to Change Orderkey  
            SET @b_Success = 2        
            GOTO QUIT_SP
         END  
      END 
   END

   /*-----------------------------------------------------------------*/
   /*   Packed By Task ID                                             */
   /*   - Input TaskId to start Pack                                  */
   /*   - Always Return Top 1 record per UseriD/Station that has Not  */
   /*     Pack Confirm                                                */
   /*   - Process Packing until pack confirm                          */
   /*   - Add New record for next packing if no pending pack record   */
   /*-----------------------------------------------------------------*/
   IF @c_PTD_ToStatus  = '9'
   BEGIN
      -- Allow to retrieve packed confirm order   
      SET @b_Success = 1
      GOTO QUIT_SP
   END 

   IF @c_PTD_ToStatus  = '3'  -- Something Wrong 'current' and 'change to' shipment order are pending records.
   BEGIN
      SET @b_Success = -1
      SET @n_Err    = 60050
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Pack By Task Batch # Error. More than 1 Pending pack record found.'
     
      GOTO QUIT_SP 
   END
    
   -- With Packed Sku 
   IF @c_PTD_ToStatus IN ('1', '2')
   BEGIN
      -- Allow to Change Orderkey  
      SET @b_Success = 2        
      GOTO QUIT_SP
   END
  
   -- Without Any Packed Sku.   
   IF @c_PTD_ToStatus = '0' 
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM PACKDETAIL WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo
                     )
      BEGIN
         -- Allow to Change Orderkey  
         SET @b_Success = 2  
         GOTO QUIT_SP
      END
   END  
     
   QUIT_SP:

   --insert into traceinfo (tracename,timein, step1, step2, step3, step4, step5)
   --values ('ETEST-Q',getdate(), @c_TaskID, @c_pickslipno, @c_orderkey, @b_Success, @c_PTD_ToStatus)

   IF @b_Success = 2
   BEGIN
      SET @c_PTD_Orderkey = @c_Orderkey

      BEGIN TRAN
      UPD_PTD:
      DECLARE CUR_UPDPTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRef
      FROM PACKTASKDETAIL  PTD WITH (NOLOCK) 
      WHERE TaskBatchNo = @c_TaskBatchNo
      AND   Orderkey = @c_PTD_Orderkey

      OPEN CUR_UPDPTD

      FETCH NEXT FROM CUR_UPDPTD INTO @n_RowRef
    
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_UPDPTD = 1
         SET @c_PTD_Status  = '0'
         SET @c_PTD_PickSlipNo = ''

         IF @c_PTD_Orderkey = @c_Orderkey
         BEGIN
            SET @c_PTD_Status     = '3'
            SET @c_PTD_PickSlipNo = @c_PickSlipNo

            IF NOT EXISTS( SELECT 1 
                           FROM PACKHEADER WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                         )
            BEGIN
               SET @b_UPDPTD = 0
            END                          
         END
         -- (Wan04) - Start Fixed: Only Allow to update from pack status - Prevention - START
         IF @c_PTD_Orderkey = @c_FromOrderkey AND @c_FromPackStatus = '9' AND @c_PTD_PickSlipNo = ''
         BEGIN 
 
            SET @b_UPDPTD = 0
         END
         -- (Wan04) - Start Fixed: Only Allow to update from pack status - Prevention - END

         IF @b_UPDPTD = 1 
         BEGIN
 
            UPDATE PACKTASKDETAIL WITH (ROWLOCK)
            SET Status     = @c_PTD_Status
               ,PickSlipNo = @c_PTD_PickSlipNo  
               ,EditWho    = SUSER_NAME() + '*'
               ,EditDate   = GETDATE()
               ,TrafficCop = NULL
            WHERE RowRef = @n_RowRef 

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 60010
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKTASKDETAIL Table. (isp_Ecom_QueryRules)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            END
         END 

         FETCH NEXT FROM CUR_UPDPTD INTO @n_RowRef
                                 
      END 
      CLOSE CUR_UPDPTD
      DEALLOCATE CUR_UPDPTD 
      
      IF @n_Continue = 1 
      BEGIN
         IF @c_PTD_Orderkey = @c_Orderkey AND @c_FromOrderkey <> ''
         -- (Wan04) - Start Fixed: Only Allow to update from pack status
         AND @c_FromPackStatus < '9' 
         -- (Wan04) - END   Fixed: Only Allow to update from pack status
         BEGIN
            SET @c_PTD_Orderkey = @c_FromOrderkey
            GOTO UPD_PTD
         END 
      END 

      IF @n_Continue = 1 
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt       --(Wan07)
   BEGIN
      BEGIN TRAN
   END 
END -- procedure

GO