SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_InsertWorkOrderJobOperation                        */
/* Creation Date: 03-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Create WorkOrderJobOperation records                          */
/*                                                                         */
/* Called By: PB After Save WorkORderJobdetail & WorkOrderJob              */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver.  Purposes                                     */
/* 04-AUG-2014  YTWan   1.1   Fixed. Sum (Step Qty) for Multi WO to 1 job  */
/*                              (Wan01)                                    */
/* 28-JAN-2016  Wan02   1.2   SOS#361845 -Project Merlion VAP Workstation*/
/*                            Inloc Assigned to Staging Lane               */
/***************************************************************************/
CREATE PROC [dbo].[isp_InsertWorkOrderJobOperation]
           @c_JobKey          NVARCHAR(10) 
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          VARCHAR(255)   OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue           INT                     
         , @n_StartTCnt          INT            -- Holds the current transaction count    

   DECLARE @c_WorkOrderkey       NVARCHAR(10)
         , @c_MasterWorkOrder    NVARCHAR(50)
         , @c_WorkOrderName      NVARCHAR(50)
         , @c_WkOrdReqInputsKey  NVARCHAR(10)
         , @c_WkOrdReqOutputsKey NVARCHAR(10)
         , @c_WkOrdInputsKey     NVARCHAR(10)
         , @c_WkOrdOuputsKey     NVARCHAR(10)
         , @b_Step               INT
         , @n_UOMQty             FLOAT
         
   DECLARE @c_JobLineNoBatchEnd  NVARCHAR(5)
         , @c_JobLineNoStartFind NVARCHAR(5)
         , @c_NewJobLineNo       NVARCHAR(5) 
         , @c_JobLineNo          NVARCHAR(5)
         , @c_StepNumber         NVARCHAR(5)
         , @c_WOOperation        NVARCHAR(30)
         , @c_StorerKey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_NonInvSku          NVARCHAR(50)
         , @c_NonInvLocation     NVARCHAR(10)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @n_StepQty            INT
         , @c_Instructions       NVARCHAR(4000)
         , @c_FromLoc            NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_CopyInputFromStep  NVARCHAR(5)
         , @c_PullType           NVARCHAR(10)       
         , @n_MinQty             INT                
         , @c_MinUOM             NVARCHAR(10)       
         , @n_PullQty            INT                
         , @c_PullUOM            NVARCHAR(10)       
         , @c_InLocation         NVARCHAR(10)       
         , @c_Rotation           NVARCHAR(10) 
         , @n_MinShelf           INT      
         , @c_Lottable01         NVARCHAR(20)       
         , @c_Lottable02         NVARCHAR(20)       
         , @c_Lottable03         NVARCHAR(20)       
         , @dt_Lottable04        DATETIME      
         , @dt_Lottable05        DATETIME 
         --(Wan) - START
         , @c_Lottable06         NVARCHAR(30)       
         , @c_Lottable07         NVARCHAR(30)       
         , @c_Lottable08         NVARCHAR(30) 
         , @c_Lottable09         NVARCHAR(30)       
         , @c_Lottable10         NVARCHAR(30)       
         , @c_Lottable11         NVARCHAR(30)   
         , @c_Lottable12         NVARCHAR(30)       
         , @dt_Lottable13        DATETIME      
         , @dt_Lottable14        DATETIME      
         , @dt_Lottable15        DATETIME 
         --(Wan) - END
         , @n_STDTime            DECIMAL(18,6)
         , @n_BillingUOMQty      INT
         , @c_BillingUOM         NVARCHAR(10)
         , @n_BillingRate        FLOAT
         , @n_ExtendedBillingQty INT
         , @n_TotalBillingAmount FLOAT
         , @n_UOMQtyJob          FLOAT

         , @n_QtyItemsOrd        INT
         , @n_QtyNonInvOrd       INT

         , @n_QtyInput           INT
         , @n_QtyJob             INT

         , @c_WorkStation           NVARCHAR(50)         --(Wan02)
         , @c_Facility              NVARCHAR(5)          --(Wan02)
         , @c_WSInLoc               NVARCHAR(10)         --(Wan02)
         , @c_SetWSInLocToVAToLoc   NVARCHAR(30)         --(Wan02)

      SET @n_Continue         = 1
      SET @n_StartTCnt        = @@TRANCOUNT  
      SET @b_Success          = 1
      SET @n_Err              = 0
      SET @c_errmsg           = ''  


      SET @c_NewJobLineNo     = '00000'
      SET @c_StepNumber       = ''   
      SET @c_WOOperation      = ''   
      SET @c_StorerKey        = ''   
      SET @c_Sku              = ''   
      SET @c_NonInvSku        = ''   
      SET @c_NonInvLocation   = ''   
      SET @c_Packkey          = ''   
      SET @c_UOM              = ''
      SET @n_StepQty          = 0   
      SET @c_Instructions     = ''   
      SET @c_FromLoc          = ''   
      SET @c_ToLoc            = ''   
      SET @c_CopyInputFromStep= ''      
      SET @c_PullType         = '' 
      SET @n_MinQty           = 0 
      SET @c_MinUOM           = ''   
      SET @n_PullQty          = 0  
      SET @c_PullUOM          = ''    
      SET @c_InLocation       = ''    
      SET @c_Rotation         = '' 
      SET @n_MinShelf         = 0  
      SET @c_Lottable01       = ''   
      SET @c_Lottable02       = ''   
      SET @c_Lottable03       = ''   
      SET @dt_Lottable04      = NULL  
      SET @dt_Lottable05      = NULL  
      --(Wan) - START
      SET @c_Lottable06       = ''        
      SET @c_Lottable07       = ''      
      SET @c_Lottable08       = ''  
      SET @c_Lottable09       = ''      
      SET @c_Lottable10       = ''   
      SET @c_Lottable11       = ''   
      SET @c_Lottable12       = ''       
      SET @dt_Lottable13      = NULL     
      SET @dt_Lottable14      = NULL 
      SET @dt_Lottable15      = NULL 
      --(Wan) - END                                
      SET @n_STDTime          = 0.000000                               
      SET @n_BillingUOMQty    = 0                               
      SET @c_BillingUOM       = ''                               
      SET @n_BillingRate      = 0.00                              
      SET @n_ExtendedBillingQty=0
      SET @n_TotalBillingAmount=0.00

      SET @n_QtyItemsOrd      = 0
      SET @n_QtyNonInvOrd     = 0

      CREATE TABLE #TEMP_WOJO
         ( SeqNo                 INT IDENTITY(1,1)
         , WorkOrderkey          NVARCHAR(10)   NULL  DEFAULT(' ')
         , MasterWorkOrder       NVARCHAR(50)   NULL  DEFAULT(' ')
         , WorkOrderName         NVARCHAR(50)   NULL  DEFAULT(' ')
         , WkOrdReqInputsKey     NVARCHAR(10)   NULL  DEFAULT(' ')
         , WkOrdReqOutputsKey    NVARCHAR(10)   NULL  DEFAULT(' ')
         , StepNumber            NVARCHAR(10)   NULL  DEFAULT(' ')
         , WOOperation           NVARCHAR(30)   NULL  DEFAULT(' ')
         , STDTime               DECIMAL(18,6)  NULL  DEFAULT(0)
         , CopyInputFromStep     NVARCHAR(5)    NULL  DEFAULT(' ')
         , FromLoc               NVARCHAR(10)   NULL  DEFAULT(' ')
         , ToLoc                 NVARCHAR(10)   NULL  DEFAULT(' ')
         , Instructions          NVARCHAR(4000) NULL  DEFAULT(' ')
         , Storerkey             NVARCHAR(15)   NULL  DEFAULT(' ')
         , Sku                   NVARCHAR(20)   NULL  DEFAULT(' ')
         , PackKey               NVARCHAR(10)   NULL  DEFAULT(' ')  
         , UOM                   NVARCHAR(10)   NULL  DEFAULT(' ')
         , InLocation            NVARCHAR(10)   NULL  DEFAULT(' ')
         , StepQty               INT            NULL  DEFAULT(0)
         , Rotation              NVARCHAR(10)   NULL  DEFAULT(' ')
         , MinShelf              INT            NULL  DEFAULT(0)
         , PullType              NVARCHAR(20)   NULL  DEFAULT(' ')
         , MinQty                INT            NULL  DEFAULT(0)
         , MinUOM                NVARCHAR(20)   NULL  DEFAULT(' ')
         , PullQty               INT            NULL  DEFAULT(0)
         , PullUOM               NVARCHAR(20)   NULL  DEFAULT(' ')
         , NonInvSku             NVARCHAR(80)   NULL  DEFAULT(' ')
         , NonInvLocation        NVARCHAR(10)   NULL  DEFAULT(' ')
         , Lottable01            NVARCHAR(20)   NULL  DEFAULT(' ')
         , Lottable02            NVARCHAR(20)   NULL  DEFAULT(' ')
         , Lottable03            NVARCHAR(20)   NULL  DEFAULT(' ')
         , Lottable04            DATETIME       NULL  DEFAULT(' ')
         , Lottable05            DATETIME       NULL  DEFAULT(' ')
         --(Wan) - START
         , Lottable06            NVARCHAR(30)   NULL  DEFAULT(' ')       
         , Lottable07            NVARCHAR(30)   NULL  DEFAULT(' ')    
         , Lottable08            NVARCHAR(30)   NULL  DEFAULT(' ')
         , Lottable09            NVARCHAR(30)   NULL  DEFAULT(' ')    
         , Lottable10            NVARCHAR(30)   NULL  DEFAULT(' ')    
         , Lottable11            NVARCHAR(30)   NULL  DEFAULT(' ') 
         , Lottable12            NVARCHAR(30)   NULL  DEFAULT(' ')      
         , Lottable13            DATETIME       NULL  DEFAULT(' ')
         , Lottable14            DATETIME       NULL  DEFAULT(' ')
         , Lottable15            DATETIME       NULL  DEFAULT(' ')
         --(Wan) - END
         , BillingUOMQty         INT            NULL  DEFAULT(0)
         , BillingUOM            NVARCHAR(20)   NULL  DEFAULT(' ')
         , BillingRate           Float          NULL  DEFAULT(0)
         , ExtendedBillingQty    INT            NULL  DEFAULT(0)
         , TotalBillingAmount    Float          NULL  DEFAULT(0)
         )

   --(Wan02) - START
   SET @c_StorerKey = ''
   SET @c_Facility  = ''
   SELECT @c_StorerKey = WOJD.Storerkey
         ,@c_Facility  = WOJD.Facility   
         ,@c_WorkStation = JS.WorkStation
   FROM WORKORDERJOBDETAIL WOJD WITH (NOLOCK)
   JOIN V_WorkOrderJobDetailSummary JS ON (WOJD.JobKey = JS.Jobkey)
   WHERE WOJD.JobKey = @c_JobKey

   SET @c_SetWSInLocToVAToLoc = ''
   SET @b_Success = 0
   Execute nspGetRight
         @c_Facility            -- facility
      ,  @c_StorerKey           -- Storerkey
      ,  NULL                   -- Sku
      ,  'SetWSInLocToVAToLoc'     -- Configkey
      ,  @b_Success              OUTPUT 
      ,  @c_SetWSInLocToVAToLoc  OUTPUT 
      ,  @n_err                  OUTPUT 
      ,  @c_ErrMsg               OUTPUT

   --(Wan02) - END
   DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT WORKORDERJOB.WorkOrderkey
         ,WORKORDERREQUEST.MasterWorkOrder 
         ,WORKORDERREQUEST.WorkOrderName
         ,WORKORDERJOB.UOMQtyJob
   FROM WORKORDERJOB WITH (NOLOCK)
   JOIN WORKORDERREQUEST WITH (NOLOCK) ON (WORKORDERJOB.WorkOrderkey = WORKORDERREQUEST.WorkOrderkey)
   WHERE WORKORDERJOB.JobKey = @c_JobKey
   AND   WORKORDERJOB.QtyJob > 0
   ORDER BY WORKORDERJOB.WorkOrderkey

   OPEN CUR_JOB

   FETCH NEXT FROM CUR_JOB INTO  @c_WorkOrderkey  
                              ,  @c_MasterWorkOrder 
                              ,  @c_WorkOrderName
                              ,  @n_UOMQtyJob
 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DECLARE CUR_STEP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WORKORDERSTEPS.StepNumber
            ,WORKORDERSTEPS.WOOperation 
            ,WORKORDERSTEPS.STDTime
            ,WORKORDERSTEPS.CopyInputFromStep
            ,WORKORDERSTEPS.FromLoc           
            ,WORKORDERSTEPS.ToLoc             
            ,WORKORDERSTEPS.Instructions
            ,WORKORDERSTEPS.BillingUOMQty
            ,WORKORDERSTEPS.BillingUOM 
            ,WORKORDERSTEPS.BillingRate
      FROM WORKORDERSTEPS  WITH (NOLOCK)
      WHERE WORKORDERSTEPS.MasterWorkOrder = @c_MasterWorkOrder
      AND   WORKORDERSTEPS.WorkOrderName = @c_WorkOrderName
      ORDER BY WORKORDERSTEPS.StepNumber

      OPEN CUR_STEP

      FETCH NEXT FROM CUR_STEP INTO  @c_StepNumber
                                  ,  @c_WOOperation
                                  ,  @n_STDTime
                                  ,  @c_CopyInputFromStep
                                  ,  @c_FromLoc           
                                  ,  @c_ToLoc             
                                  ,  @c_Instructions
                                  ,  @n_BillingUOMQty     
                                  ,  @c_BillingUOM        
                                  ,  @n_BillingRate
                         
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_Step = 1
         ----------------
         --<<  Input >>--
         ----------------
         DECLARE CUR_INPUT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT WkOrdInputsKey
         FROM WORKORDERINPUTS WITH (NOLOCK)
         WHERE MasterWorkOrder = @c_MasterWorkOrder
         AND   WorkOrderName = @c_WorkOrderName
         AND   StepNumber    = @c_StepNumber
         ORDER BY StepNumber

         OPEN CUR_INPUT

         FETCH NEXT FROM CUR_INPUT INTO  @c_WkOrdInputsKey
 
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            --(Wan02) - START
            --SET @c_WSInLoc = @c_ToLoc
            IF @c_SetWSInLocToVAToLoc = '1' AND @c_ToLoc <> ''
            BEGIN
               SELECT TOP 1 @c_ToLoc = Location
               FROM WORKSTATIONLOC WITH (NOLOCK)
               WHERE Facility = @c_Facility
               AND   WorkStation = @c_WorkStation
               AND   LocType = 'InLoc'
               AND   Location <> '' AND Location IS NOT NULL
            END
            --(Wan02) - END

            SELECT @n_UOMQty = WORKORDERREQUEST.UOMQty
            FROM WORKORDERREQUEST WITH (NOLOCK)
            WHERE WORKORDERREQUEST.WorkOrderkey = @c_WorkOrderkey

            SET @b_Step = 0
            INSERT INTO #TEMP_WOJO 
               ( WorkOrderkey
               , MasterWorkOrder 
               , WorkOrderName
               , WkOrdReqInputsKey
               , StepNumber                                                        
               , WOOperation                                                       
               , STDTime                                                           
               , FromLoc                                                           
               , ToLoc                                                             
               , Instructions                                                      
               , Storerkey                                                         
               , Sku                                                               
               , PackKey                                                           
               , UOM                                                               
               , InLocation                                                        
               , StepQty                                                           
               , Rotation                                                          
               , MinShelf                                                          
               , PullType                                                          
               , MinQty                                                            
               , MinUOM                                                            
               , PullQty                                                           
               , PullUOM                                                           
               , NonInvSku                                                         
               , NonInvLocation                                                    
               , Lottable01                                                        
               , Lottable02                                                        
               , Lottable03                                                        
               , Lottable04                                                        
               , Lottable05  
               --(Wan) - START
               , Lottable06                
               , Lottable07               
               , Lottable08          
               , Lottable09            
               , Lottable10          
               , Lottable11          
               , Lottable12             
               , Lottable13             
               , Lottable14           
               , Lottable15         
               --(Wan) - END
               , BillingUOMQty                                                     
               , BillingUOM                                                        
               , BillingRate                                                       
               , ExtendedBillingQty                                                
               , TotalBillingAmount 
               )
         SELECT WorkOrderkey   = @c_WorkOrderkey
               , MasterWorkOrder= @c_MasterWorkOrder 
               , WorkOrderName  = @c_WorkOrderName
               , WkOrdReqInputsKey=WORKORDERREQUESTINPUTS.WkOrdReqInputsKey
               , StepNumber    = @c_StepNumber
               , WOOperation   = @c_WOOperation
               , STDTime       = @n_STDTime
               , FromLoc       = @c_FromLoc           
               , ToLoc         = @c_ToLoc            
               , Instructions  = @c_Instructions
               , Storerkey     = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Storerkey),'')
               , SKU           = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.SKU),'')              
               , PackKey       = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.PackKey),'')          
               , UOM           = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.UOM),'')              
               , InLocation    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.InLocation),'')
               , StepQty       = CEILING(ISNULL(WORKORDERREQUESTINPUTS.Qty/@n_UOMQty,0) * (ISNULL(WORKORDERREQUESTINPUTS.Wastage,0)/100) * @n_UOMQtyJob) 
                                         + (ISNULL(WORKORDERREQUESTINPUTS.Qty/@n_UOMQty,0) * @n_UOMQtyJob)
                                         +  ISNULL(WORKORDERREQUESTINPUTS.QtyAddOn,0)
                                 --CASE WHEN WORKORDERREQUESTINPUTS.WkOrdInputsKey = ''
                                 --     THEN CEILING(WORKORDERREQUESTINPUTS.Qty + ((WORKORDERREQUESTINPUTS.Wastage/100) * WORKORDERREQUESTINPUTS.Qty))
                                 --     ELSE CEILING(ISNULL(@n_UOMQty,0) * (ISNULL(WORKORDERREQUESTINPUTS.Wastage,0)/100) * UOMQtyJob)  
                                 --        + (ISNULL(@n_UOMQty,0) * UOMQtyJob)
                                 --     END                                        
               , Rotation      = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Rotation),'') 
               , MinShelf      = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.MinShelf),'')                   
               , PullType      = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.PullType),'')         
               , MinQty        = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.MinQty),'')           
               , MinUOM        = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.MinUOM),'')           
               , PullQty       = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.PullQty),'')          
               , PullUOM       = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.PullUOM),'')  
               , NonInvSku     = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.NonInvSku),'') 
               , NonInvLocation= ISNULL(RTRIM(WORKORDERREQUESTINPUTS.NonInvLocation),'')
               , Lottable01    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable01),'') 
               , Lottable02    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable02),'') 
               , Lottable03    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable03),'') 
               , Lottable04    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable04),'') 
               , Lottable05    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable05),'') 
               --(Wan) - START
               , Lottable06    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable06),'')           
               , Lottable07    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable07),'')     
               , Lottable08    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable08),'') 
               , Lottable09    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable09),'')   
               , Lottable10    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable10),'')
               , Lottable11    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable11),'')   
               , Lottable12    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable12),'')    
               , Lottable13    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable13),'')    
               , Lottable14    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable14),'')     
               , Lottable15    = ISNULL(RTRIM(WORKORDERREQUESTINPUTS.Lottable15),'') 
               --(Wan) - END
               , BillingUOMQty = @n_BillingUOMQty     
               , BillingUOM    = @c_BillingUOM        
               , BillingRate   = @n_BillingRate
               , ExtendedBillingQty = CASE WHEN @c_BillingUOM = 'Time' THEN 0 
                                           ELSE @n_BillingUOMQty * ISNULL(WORKORDERREQUESTINPUTS.QtyCompleted,0)
                                           END 
               , TotalBillingAmount = CASE WHEN @c_BillingUOM = 'Time' THEN 0 
                                           ELSE @n_BillingUOMQty * ISNULL(WORKORDERREQUESTINPUTS.QtyCompleted,0) * @n_BillingRate
                                           END
            FROM WORKORDERREQUESTINPUTS WITH (NOLOCK)
            LEFT JOIN VASREFKEYLOOKUP  WITH (NOLOCK) ON (VASREFKEYLOOKUP.Jobkey = @c_JobKey)
                                                     AND(WORKORDERREQUESTINPUTS.WorkOrderKey = VASREFKEYLOOKUP.WorkOrderKey)
                                                     AND(WORKORDERREQUESTINPUTS.WkOrdReqInputsKey = VASREFKEYLOOKUP.WkOrdReqInputsKey)
            WHERE WORKORDERREQUESTINPUTS.WorkOrderkey  = @c_WorkOrderkey 
            AND   (WORKORDERREQUESTINPUTS.WkOrdInputsKey= @c_WkOrdInputsKey OR WORKORDERREQUESTINPUTS.WkOrdInputsKey = '')
            AND   WORKORDERREQUESTINPUTS.StepNumber    = @c_StepNumber
            AND   VASREFKEYLOOKUP.WorkOrderkey IS NULL

            FETCH NEXT FROM CUR_INPUT INTO  @c_WkOrdInputsKey

         END
         CLOSE CUR_INPUT
         DEALLOCATE CUR_INPUT

         ----------------
         --<< Output >>--
         ----------------

         INSERT INTO #TEMP_WOJO 
               ( WorkOrderkey
               , MasterWorkOrder 
               , WorkOrderName
               , WkOrdReqOutputsKey
               , StepNumber                                                        
               , WOOperation                                                       
               , STDTime                                                           
               , FromLoc                                                           
               , ToLoc                                                             
               , Instructions                                                      
               , BillingUOMQty                                                     
               , BillingUOM                                                        
               , BillingRate                                                       
               , ExtendedBillingQty                                                
               , TotalBillingAmount 
               )
         SELECT WorkOrderkey    = @c_WorkOrderkey
             ,  MasterWorkOrder = @c_MasterWorkOrder 
             ,  WorkOrderName   = @c_WorkOrderName
             ,  WkOrdReqOutpustKey= WORKORDERREQUESTOUTPUTS.WkOrdReqOutputsKey
             ,  StepNumber      = @c_StepNumber
             ,  WOOperation     = @c_WOOperation
             ,  STDTime         = @n_STDTime
             ,  FromLoc         = @c_FromLoc           
             ,  ToLoc           = @c_ToLoc             
             ,  Instructions    = @c_Instructions
             ,  BillingUOMQty   = ISNULL(WORKORDERREQUESTOUTPUTS.BillingUOMQty, @n_BillingUOMQty)     
             ,  BillingUOM      = ISNULL(RTRIM(WORKORDERREQUESTOUTPUTS.BillingUOM), @c_BillingUOM)        
             ,  BillingRate     = ISNULL(WORKORDERREQUESTOUTPUTS.BillingRate, @n_BillingRate)
             ,  ExtendedBillingQty = CASE WHEN BillingUOM = 'Time' THEN 0 
                                          ELSE ISNULL(BillingUOMQty,@n_BillingUOMQty) * ISNULL(QtyCompleted,0)
                                          END 
             ,  TotalBillingAmount = CASE WHEN BillingUOM = 'Time' THEN 0 
                                          ELSE ISNULL(BillingUOMQty,@n_BillingUOMQty) * ISNULL(QtyCompleted,0) * ISNULL(BillingRate,@n_BillingRate)
                                          END
         FROM WORKORDERREQUESTOUTPUTS WITH (NOLOCK)
         LEFT JOIN VASREFKEYLOOKUP WITH (NOLOCK) ON (VASREFKEYLOOKUP.Jobkey = @c_JobKey)
                                                 AND(WORKORDERREQUESTOUTPUTS.WorkOrderKey = VASREFKEYLOOKUP.WorkOrderKey)
                                                 AND(WORKORDERREQUESTOUTPUTS.WkOrdReqOutputsKey = VASREFKEYLOOKUP.WkOrdReqOutputsKey)

         WHERE WORKORDERREQUESTOUTPUTS.WorkOrderkey = @c_WorkOrderkey 
         AND   WORKORDERREQUESTOUTPUTS.StepNumber   = @c_StepNumber
         AND   VASREFKEYLOOKUP.WorkOrderkey IS NULL

         IF @@ROWCOUNT > 0 
         BEGIN
            SET @b_Step = 0
         END
         ----------------
         --<<  Step  >>--
         ----------------
         IF @b_Step = 1
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM VASREFKEYLOOKUP WITH (NOLOCK) 
                            WHERE VASREFKEYLOOKUP.Jobkey = @c_JobKey 
                                              AND VASREFKEYLOOKUP.MasterWorkOrder = @c_MasterWorkOrder
                                              AND VASREFKEYLOOKUP.WorkOrderName = WorkOrderName 
                                              AND VASREFKEYLOOKUP.StepNumber = @c_StepNumber )
            BEGIN
               INSERT INTO #TEMP_WOJO
                     ( WorkOrderkey
                     , MasterWorkOrder 
                     , WorkOrderName
                     , StepNumber                                                        
                     , WOOperation                                                       
                     , STDTime 
                     , CopyInputFromStep                                                           
                     , FromLoc                                                           
                     , ToLoc                                                             
                     , Instructions                                                      
                     , BillingUOMQty                                                     
                     , BillingUOM                                                        
                     , BillingRate                                                       
                     )
               VALUES( @c_WorkOrderkey
                   ,   @c_MasterWorkOrder 
                   ,   @c_WorkOrderName
                   ,   @c_StepNumber
                   ,   @c_WOOperation
                   ,   @n_STDTime
                   ,   @c_CopyInputFromStep 
                   ,   @c_FromLoc           
                   ,   @c_ToLoc             
                   ,   @c_Instructions 
                   ,   @n_BillingUOMQty     
                   ,   @c_BillingUOM        
                   ,   @n_BillingRate
                     )
            END
         END

         FETCH NEXT FROM CUR_STEP INTO  @c_StepNumber
                                     ,  @c_WOOperation
                                     ,  @n_STDTime
                                     ,  @c_CopyInputFromStep
                                     ,  @c_FromLoc           
                                     ,  @c_ToLoc             
                                     ,  @c_Instructions
                                     ,  @n_BillingUOMQty     
                                     ,  @c_BillingUOM        
                                     ,  @n_BillingRate
      END
      CLOSE CUR_STEP
      DEALLOCATE CUR_STEP       
      
      FETCH NEXT FROM CUR_JOB INTO  @c_WorkOrderkey  
                                 ,  @c_MasterWorkOrder 
                                 ,  @c_WorkOrderName
                                 ,  @n_UOMQtyJob
   END
   CLOSE CUR_JOB
   DEALLOCATE CUR_JOB
   
   SET @c_JobLineNoBatchEnd = ''
   SELECT @c_JobLineNoBatchEnd = ISNULL(MAX(JobLine),'')
   FROM WORKORDERJOBOPERATION WITH (NOLOCK)
   WHERE Jobkey = @c_JobKey

   SET @c_NewJobLineNo = @c_JobLineNoBatchEnd

   DECLARE WOJO_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  MasterWorkOrder 
         , WorkOrderName
         , WorkOrderKey
         , WkOrdReqInputsKey
         , WkOrdReqOutputsKey
         , StepNumber  
         , WOOperation       
         , STDTime           
         , CopyInputFromStep 
         , FromLoc           
         , ToLoc             
         , Instructions
         , Storerkey           
         , Sku                 
         , PackKey                
         , UOM                    
         , InLocation          
         , StepQty            
         , Rotation            
         , MinShelf                 
         , PullType              
         , MinQty                  
         , MinUOM                   
         , PullQty                      
         , PullUOM                     
         , NonInvSku          
         , NonInvLocation       
         , Lottable01          
         , Lottable02         
         , Lottable03           
         , Lottable04           
         , Lottable05 
          --(Wan) - START
          , Lottable06                  
          , Lottable07            
          , Lottable08        
          , Lottable09         
          , Lottable10      
          , Lottable11       
          , Lottable12          
          , Lottable13         
          , Lottable14         
          , Lottable15        
          --(Wan) - END
         , BillingUOMQty     
         , BillingUOM        
         , BillingRate            
         , ExtendedBillingQty 
         , TotalBillingAmount
   FROM #TEMP_WOJO
   ORDER BY MasterWorkOrder
         , StepNumber 
         , WorkOrderName
         , WkOrdReqInputsKey
         , WkOrdReqOutputsKey
         , STDTime           
         , CopyInputFromStep 
         , FromLoc           
         , ToLoc             
         , Instructions
         , Storerkey           
         , Sku                 
         , PackKey                
         , UOM                    
         , InLocation          
         , Rotation            
         , MinShelf                 
         , PullType              
         , MinQty                  
         , MinUOM                   
         , PullQty                      
         , PullUOM                     
         , NonInvSku          
         , NonInvLocation       
         , Lottable01          
         , Lottable02         
         , Lottable03           
         , Lottable04           
         , Lottable05 
          --(Wan) - START
          , Lottable06                  
          , Lottable07            
          , Lottable08        
          , Lottable09         
          , Lottable10      
          , Lottable11       
          , Lottable12          
          , Lottable13         
          , Lottable14         
          , Lottable15        
          --(Wan) - END
         , BillingUOMQty     
         , BillingUOM        
         , BillingRate       
   

   OPEN WOJO_CUR
   FETCH NEXT FROM WOJO_CUR INTO   @c_MasterWorkOrder 
                                 , @c_WorkOrderName
                                 , @c_WorkOrderKey
                                 , @c_WkOrdReqInputsKey
                                 , @c_WkOrdReqOutputsKey
                                 , @c_StepNumber
                                 , @c_WOOperation       
                                 , @n_STDTime           
                                 , @c_CopyInputFromStep 
                                 , @c_FromLoc           
                                 , @c_ToLoc             
                                 , @c_Instructions 
                                 , @c_Storerkey
                                 , @c_SKU              
                                 , @c_PackKey          
                                 , @c_UOM              
                                 , @c_InLocation
                                 , @n_StepQty       
                                 , @c_Rotation
                                 , @n_MinShelf         
                                 , @c_PullType         
                                 , @n_MinQty           
                                 , @c_MinUOM           
                                 , @n_PullQty          
                                 , @c_PullUOM
                                 , @c_NonInvSku  
                                 , @c_NonInvLocation
                                 , @c_Lottable01      
                                 , @c_Lottable02      
                                 , @c_Lottable03      
                                 , @dt_Lottable04      
                                 , @dt_Lottable05
                                 , @c_Lottable06 
                                 , @c_Lottable07 
                                 , @c_Lottable08 
                                 , @c_Lottable09 
                                 , @c_Lottable10 
                                 , @c_Lottable11 
                                 , @c_Lottable12 
                                 , @dt_Lottable13
                                 , @dt_Lottable14
                                 , @dt_Lottable15
                                 , @n_BillingUOMQty     
                                 , @c_BillingUOM        
                                 , @n_BillingRate 
                                 , @n_ExtendedBillingQty 
                                 , @n_TotalBillingAmount
   
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      SET @c_JobLineNo = ''

      SET @c_JobLineNoStartFind = @c_JobLineNoBatchEnd
      IF @c_WOOperation = 'begin fg'
      BEGIN 
         SET @c_JobLineNoStartFind = ''
      END 

      SELECT @c_JobLineNo = JobLine
      FROM WORKORDERJOBOPERATION WITH (NOLOCK)
      WHERE JobKey           = @c_JobKey
      AND   WOOperation      = @c_WOOperation  
      AND   StorerKey        = @c_Storerkey  
      AND   Sku              = @c_Sku                             
      AND   NonInvSku        = @c_NonInvSku                       
      AND   NonInvLocation   = @c_NonInvLocation                  
      AND   Packkey          = @c_Packkey                         
      AND   UOM              = @c_UOM                             
      AND   Instructions     = @c_Instructions                    
      AND   FromLoc          = @c_FromLoc                         
      AND   ToLoc            = @c_ToLoc                           
      AND   CopyInputFromStep= @c_CopyInputFromStep               
      AND   PullType         = @c_PullType                        
      AND   MinQty           = @n_MinQty                          
      AND   MinUOM           = @c_MinUOM                          
      AND   PullQty          = @n_PullQty                         
      AND   PullUOM          = @c_PullUOM                         
      AND   InLocation       = @c_InLocation                      
      AND   Rotation         = @c_Rotation                        
      AND   MinShelf         = @n_MinShelf                        
      AND   Lottable01       = @c_Lottable01                      
      AND   Lottable02       = @c_Lottable02                      
      AND   Lottable03       = @c_Lottable03  
      AND   Lottable04       = @dt_Lottable04                     
      AND   Lottable05       = @dt_Lottable05 
      AND   Lottable06       = @c_Lottable06                      
      AND   Lottable07       = @c_Lottable07                      
      AND   Lottable08       = @c_Lottable08
      AND   Lottable09       = @c_Lottable09                      
      AND   Lottable10       = @c_Lottable10
      AND   Lottable11       = @c_Lottable11                      
      AND   Lottable12       = @c_Lottable12                      
      AND   Lottable13       = @dt_Lottable13
      AND   Lottable14       = @dt_Lottable14                     
      AND   Lottable15       = @dt_Lottable15                     
      AND   STDTime          = @n_STDTime                         
      AND   BillingUOMQty    = @n_BillingUOMQty                   
      AND   BillingUOM       = @c_BillingUOM                      
      AND   BillingRate      = @n_BillingRate  
      AND   JobLine          > @c_JobLineNoStartFind                   

      IF @c_JobLineNo = ''
      BEGIN  
         SET @c_NewJobLineNo = RIGHT('00000' + CONVERT(VARCHAR(5),CONVERT(INT, @c_NewJobLineNo) + 1), 5)

         INSERT INTO WORKORDERJOBOPERATION   
             (  JobKey           
               ,JobLine        
               ,MinStep          
               ,WOOperation      
               ,StorerKey        
               ,Sku              
               ,NonInvSku        
               ,NonInvLocation   
               ,Packkey          
               ,UOM  
               ,StepQty
               ,QtyToProcess
               ,QtyInProcess
               ,QtyCompleted 
               ,PendingTasks
               ,InProcessTasks
               ,CompletedTasks           
               ,Instructions     
               ,FromLoc          
               ,ToLoc            
               ,CopyInputFromStep
               ,JobStatus
               ,PullType         
               ,MinQty           
               ,MinUOM           
               ,PullQty          
               ,PullUOM 
               ,InLocation       
               ,Rotation
               ,MinShelf          
               ,Lottable01       
               ,Lottable02       
               ,Lottable03       
               ,Lottable04       
               ,Lottable05 
               ,Lottable06                  
               ,Lottable07            
               ,Lottable08        
               ,Lottable09         
               ,Lottable10      
               ,Lottable11       
               ,Lottable12          
               ,Lottable13         
               ,Lottable14         
               ,Lottable15                       
               ,STDTime 
               ,EstimatedDuration 
               ,RemainingDuration                             
               ,BillingUOMQty                  
               ,BillingUOM                      
               ,BillingRate
               ,ExtendedBillingQty 
               ,TotalBillingAmount  
             ) 
         VALUES (  @c_JobKey           
               ,@c_NewJobLineNo        
               ,@c_StepNumber          
               ,@c_WOOperation      
               ,@c_StorerKey        
               ,@c_Sku              
               ,@c_NonInvSku        
               ,@c_NonInvLocation   
               ,@c_Packkey          
               ,@c_UOM  
               ,@n_StepQty
               --,@n_StepQty
               ,0
               ,0
               ,0
               ,0
               ,0
               ,0            
               ,@c_Instructions     
               ,@c_FromLoc          
               ,@c_ToLoc            
               ,@c_CopyInputFromStep
               ,'0'
               ,@c_PullType         
               ,@n_MinQty           
               ,@c_MinUOM           
               ,@n_PullQty          
               ,@c_PullUOM          
               ,@c_InLocation       
               ,@c_Rotation 
               ,@n_MinShelf        
               ,@c_Lottable01       
               ,@c_Lottable02       
               ,@c_Lottable03       
               ,@dt_Lottable04       
               ,@dt_Lottable05 
               ,@c_Lottable06 
               ,@c_Lottable07 
               ,@c_Lottable08 
               ,@c_Lottable09 
               ,@c_Lottable10 
               ,@c_Lottable11 
               ,@c_Lottable12 
               ,@dt_Lottable13
               ,@dt_Lottable14
               ,@dt_Lottable15                     
               ,@n_STDTime 
               ,@n_STDTime * @n_StepQty 
               ,0                             
               ,@n_BillingUOMQty                  
               ,@c_BillingUOM                      
               ,@n_BillingRate
               ,@n_ExtendedBillingQty
               ,@n_TotalBillingAmount   
              )   

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
           SET @n_continue= 3
           SET @n_err     = 63700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Insert Failed On Table WORKORDERJOBOPERATION. (isp_InsertWorkOrderJobOperation)' 
           GOTO QUIT
         END 
         SET @c_JobLineNo = @c_NewJobLineNo
      END
      ELSE
      BEGIN
         UPDATE  WORKORDERJOBOPERATION WITH (ROWLOCK)
         SET   StepQty = StepQty + @n_StepQty
              --,QtyToProcess = QtyToProcess + @n_StepQty
              ,EstimatedDuration = EstimatedDuration + (STDTime * @n_StepQty) 
              ,ExtendedBillingQty = ExtendedBillingQty + @n_ExtendedBillingQty
              ,TotalBillingAmount = TotalBillingAmount + @n_TotalBillingAmount 
              ,EditWho     = SUSER_NAME()
              ,EditDate    = GETDATE()  
         WHERE JobKey           = @c_JobKey
         AND   JobLine          = @c_JobLineNo

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_InsertWorkOrderJobOperation)' 
            GOTO QUIT
         END  
      END

      INSERT INTO VASREFKEYLOOKUP (JobKey, JobLine, WorkOrderkey, WorkOrderName, MasterWorkOrder, WkOrdReqInputsKey, WkOrdReqOutputsKey, StepNumber, StepQty)
      VALUES( @c_JobKey, @c_JobLineNo, @c_WorkOrderKey, @c_WorkOrderName, @c_MasterWorkOrder, @c_WkOrdReqInputsKey, @c_WkOrdReqOutputsKey, @c_StepNumber, @n_StepQty)

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Insert Failed On Table VASREFKEYLOOKUP. (isp_InsertWorkOrderJobOperation)' 
         GOTO QUIT
      END  

      IF @c_WkOrdReqInputsKey <> ''
      BEGIN
         SET @n_QtyInput = 0
         SELECT @n_QtyInput = Qty
               ,@n_QtyJob = QtyJob
         FROM WORKORDERREQUESTINPUTS WITH (NOLOCK)
         WHERE WkOrdReqInputsKey = @c_WkOrdReqInputsKey

         IF @n_QtyJob = 0 AND @n_QtyInput > 0
         BEGIN
            SELECT @n_UOMQty = UOMQty
            FROM WORKORDERREQUEST WITH (NOLOCK)
            WHERE WorkOrderkey = @c_WorkOrderKey

            SELECT @n_QtyJob = QtyJob
            FROM WORKORDERJOBDETAIL WITH (NOLOCK)
            WHERE JobKey = @c_JobKey

            SET @n_QtyJob = ( @n_QtyInput / @n_UOMQty ) * @n_QtyJob

            UPDATE WORKORDERREQUESTINPUTS WITH (ROWLOCK) 
            SET QtyJob  = @n_QtyJob
               ,EditWho      = SUSER_NAME()
               ,EditDate     = GETDATE()
               ,Trafficcop   = NULL
            WHERE WkOrdReqInputsKey = @c_WkOrdReqInputsKey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63715   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUESTINPUTS. (isp_InsertWorkOrderJobOperation)' 
               GOTO QUIT
            END  
         END
      END

      FETCH NEXT FROM WOJO_CUR INTO   @c_MasterWorkOrder 
                                    , @c_WorkOrderName
                                    , @c_WorkOrderKey
                                    , @c_WkOrdReqInputsKey
                                    , @c_WkOrdReqOutputsKey
                                    , @c_StepNumber
                                    , @c_WOOperation       
                                    , @n_STDTime           
                                    , @c_CopyInputFromStep 
                                    , @c_FromLoc           
                                    , @c_ToLoc             
                                    , @c_Instructions 
                                    , @c_Storerkey
                                    , @c_SKU              
                                    , @c_PackKey          
                                    , @c_UOM              
                                    , @c_InLocation
                                    , @n_StepQty       
                                    , @c_Rotation
                                    , @n_MinShelf         
                                    , @c_PullType         
                                    , @n_MinQty           
                                    , @c_MinUOM           
                                    , @n_PullQty          
                                    , @c_PullUOM
                                    , @c_NonInvSku  
                                    , @c_NonInvLocation
                                    , @c_Lottable01      
                                    , @c_Lottable02      
                                    , @c_Lottable03      
                                    , @dt_Lottable04      
                                    , @dt_Lottable05
                                    , @c_Lottable06 
                                    , @c_Lottable07 
                                    , @c_Lottable08 
                                    , @c_Lottable09 
                                    , @c_Lottable10 
                                    , @c_Lottable11 
                                    , @c_Lottable12 
                                    , @dt_Lottable13
                                    , @dt_Lottable14
                                    , @dt_Lottable15
                                    , @n_BillingUOMQty     
                                    , @c_BillingUOM        
                                    , @n_BillingRate
                                    , @n_ExtendedBillingQty 
                                    , @n_TotalBillingAmount   
   END 
   CLOSE WOJO_CUR
   DEALLOCATE WOJO_CUR

--   SELECT  @n_QtyItemsOrd = SUM(CASE WHEN RTRIM(SKU) <> '' THEN StepQty ELSE 0 END)
--         , @n_QtyNonInvOrd= SUM(CASE WHEN RTRIM(NonInvSku) <> '' THEN StepQty ELSE 0 END)       
--   FROM WORKORDERJOBOPERATION WITH (NOLOCK)
--   WHERE JobKey = @c_JobKey
--   --AND JobLine > @c_JobLineNoBatchEnd
--
--
--   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
--   SET QtyItemsOrd  = @n_QtyItemsOrd
--      ,QtyItemsNeed = @n_QtyItemsOrd  - QtyItemsRes
--      ,QtyNonInvOrd = @n_QtyNonInvOrd
--      ,QtyNonInvNeed= @n_QtyNonInvOrd - QtyNonInvRes
--      ,EditWho      = SUSER_NAME()
--      ,EditDate     = GETDATE()
--      ,Trafficcop   = NULL
--   WHERE JobKey = @c_Jobkey
--
--   SET @n_err = @@ERROR
--
--   IF @n_err <> 0
--   BEGIN
--      SET @n_continue= 3
--      SET @n_err     = 63720  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (isp_InsertWorkOrderJobOperation)' 
--      GOTO QUIT
--   END  

   QUIT:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_InsertWorkOrderJobOperation'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END

GO