SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Function: isp_JobInvReconSummary                                           */    
/* Creation Date: 05-OCT-2015                                                 */    
/* Copyright: LFL                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose:                                                                   */    
/*                                                                            */    
/* Input Parameters:@c_JobKey                                                 */    
/*                                                                            */    
/* OUTPUT Parameters:                                                         */    
/*                                                                            */    
/* Return Status: NONE                                                        */    
/*                                                                            */    
/* Usage:                                                                     */    
/*                                                                            */    
/* Local Variables:                                                           */    
/*                                                                            */    
/* Called By: When Retrieve Records                                           */    
/*                                                                            */    
/* PVCS Version: 1.0                                                          */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author  Ver   Purposes                                        */ 
/* 29-FEB-2016  Wan01   1.1   SOS#364219 - Project Merlion û VAP Add Qty Call */
/*                            Out Inv Recon                                   */
/* 09-MAR-2016  Wan02   1.2   Fixed.                                          */
/******************************************************************************/    
CREATE PROC [dbo].[isp_JobInvReconSummary]
(  @c_JobKey  NVARCHAR(10)
) 
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_WorkOrderkey       NVARCHAR(10)
         , @c_JobLineNo          NVARCHAR(5)
         , @c_FGStorerkey        NVARCHAR(15)
         , @c_FGSku              NVARCHAR(20)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_SkuDescr           NVARCHAR(80)
         , @c_NonInvSku          NVARCHAR(80)
         , @n_QtyReserved        INT
         , @n_QtyUncased         INT
         , @n_QtyWastage         INT   
         , @n_QtyReject          INT
         , @n_QtyRemaining       INT
         , @n_QtyComsumed        INT
         , @n_FGToProduce        INT
         , @n_CompletedFG        INT
         , @n_WOUOMQty           INT
         , @n_WOInputQty         INT
         , @n_BOMQty             INT
         , @n_UOMQtyJob          INT
         , @n_QtyJob             INT
         , @n_QtyCompleted       INT
         , @n_Discrepancy        INT
         , @c_WkOrdReqInputsKey  NVARCHAR(10)
         , @n_PalletQty          INT               --(Wan01)


   CREATE TABLE #TEMP_RECON
      (  JobKey         NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  Storerkey      NVARCHAR(15)   NOT NULL DEFAULT('') 
      ,  SkuType        NVARCHAR(10)   NOT NULL DEFAULT('I')   
      ,  Sku            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  SkuDescr       NVARCHAR(80)   NOT NULL DEFAULT('')
      ,  NonInvSku      NVARCHAR(80)   NOT NULL DEFAULT('')
      ,  QtyReserved    INT            NULL     DEFAULT(0)
      ,  QtyUncased     INT            NULL     DEFAULT(0)
      ,  QtyWastage     INT            NULL     DEFAULT(0)
      ,  QtyReject      INT            NULL     DEFAULT(0)
      ,  QtyRemaining   INT            NULL     DEFAULT(0)
      ,  QtyComsumed    INT            NULL     DEFAULT(0) 
      ,  FGToProduce    INT            NULL     DEFAULT(0)
      ,  CompletedFG    INT            NULL     DEFAULT(0) 
      ,  Discrepancy    INT            NULL     DEFAULT(0) 
      ,  PalletQty      INT            NULL     DEFAULT(0)        --(Wan01)
      ) 

   --(Wan01) - START
   CREATE TABLE #TEMP_UNCASED
      (  JobKey         NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  Storerkey      NVARCHAR(15)   NOT NULL DEFAULT('') 
      ,  Sku            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Qty            INT            NULL     DEFAULT(0)  
      ,  SystemQty      INT            NULL     DEFAULT(0)        
      ) 
   --(Wan01) - END

   SET @n_QtyReserved  = 0
   SET @n_QtyWastage   = 0
   SET @n_QtyReject    = 0
   SET @n_QtyRemaining = 0
   SET @n_QtyComsumed  = 0
   SET @n_FGToProduce  = 0
   SET @n_CompletedFG  = 0
   SET @n_BOMQty       = 0


   --(Wan01) - START
   INSERT INTO #TEMP_UNCASED
            (JobKey
            ,Storerkey
            ,Sku
            ,ID
            ,Qty
            ,SystemQty
            )
   SELECT JobKey
         ,Storerkey
         ,Sku
         ,ID
         ,ISNULL(SUM(Qty),0)
         ,ISNULL(MAX(SystemQty),0)
   FROM WORKORDER_UNCASING WITH (NOLOCK)
   WHERE JobKey = @c_JobKey
   GROUP BY JobKey, Storerkey, Sku, ID
   --(Wan01) - END

   DECLARE CUR_RECON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT WORKORDERJOBOPERATION.Storerkey
         ,WORKORDERJOBOPERATION.Sku
         ,WORKORDERJOBOPERATION.NonInvSku
         ,QtyReserved = ISNULL(SUM(WORKORDERJOBOPERATION.QtyReserved),0)
         ,QtyWastage  = ISNULL(SUM(WORKORDERJOBRECON.QtyWastage),0) 
         ,QtyReject   = ISNULL(SUM(WORKORDERJOBRECON.QtyReject),0)
         ,QtyRemaining= ISNULL(SUM(WORKORDERJOBRECON.QtyRemaining),0)
   FROM WORKORDERJOBOPERATION WITH (NOLOCK)
   LEFT JOIN WORKORDERJOBRECON     WITH (NOLOCK) ON (WORKORDERJOBOPERATION.JobKey = WORKORDERJOBRECON.Jobkey)
                                                 AND(WORKORDERJOBOPERATION.Storerkey = WORKORDERJOBRECON.Storerkey)
                                                 AND(WORKORDERJOBOPERATION.Sku = WORKORDERJOBRECON.Sku)
                                                 AND(WORKORDERJOBOPERATION.NonInvSku = WORKORDERJOBRECON.NonInvSku)
   WHERE WORKORDERJOBOPERATION.JobKey  = @c_JobKey
   AND (WORKORDERJOBOPERATION.Sku <> '' OR WORKORDERJOBOPERATION.NonInvSku <> '')
--   OR    WORKORDERJOBOPERATION.WOOperation = 'Begin FG')
   GROUP BY WORKORDERJOBOPERATION.Storerkey
         ,  WORKORDERJOBOPERATION.Sku
         ,  WORKORDERJOBOPERATION.NonInvSku

   OPEN CUR_RECON

   FETCH NEXT FROM CUR_RECON INTO  @c_Storerkey
                                 , @c_Sku
                                 , @c_NonInvSku
                                 , @n_QtyReserved
                                 , @n_QtyWastage
                                 , @n_QtyReject
                                 , @n_QtyRemaining
 
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @n_QtyComsumed = 0

      SET @n_QtyUncased = 0
      SET @n_PalletQty  = 0                           --(Wan01)
      SELECT @n_QtyUncased = ISNULL(SUM(Qty),0)       
            ,@n_PalletQty  = ISNULL(SUM(SystemQty),0) --(Wan02)
      FROM #TEMP_UNCASED                              --(Wan01)
      WHERE JobKey = @c_JobKey
      AND Storerkey = @c_Storerkey
      AND Sku = @c_Sku
      GROUP BY Jobkey, Storerkey, Sku                 --(Wan02)     

      DECLARE CUR_WOJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT VLKUP.WorkOrderKey 
            ,VLKUP.WkOrdReqInputsKey
            ,WOJ.UOMQtyJob
            ,WOJ.QtyJob
            ,WOJ.QtyCompleted
      FROM WORKORDERJOBOPERATION WOJO  WITH (NOLOCK)
      JOIN VASREFKEYLOOKUP       VLKUP WITH (NOLOCK) ON (WOJO.JobKey  = VLKUP.JobKey)
                                                     AND(WOJO.JobLine = VLKUP.JobLine)
      JOIN WORKORDERJOB          WOJ   WITH (NOLOCK) ON (VLKUP.JobKey = WOJ.JobKey)
                                                     AND(VLKUP.WorkOrderKey = WOJ.WorkOrderKey)
      WHERE WOJO.JobKey = @c_JobKey
      AND   WOJO.Storerkey= @c_Storerkey
      AND   WOJO.Sku      = @c_Sku
      AND   WOJO.NonInvSku= @c_NonInvSku
      AND   WOJ.QtyJob > 0  
      ORDER BY WOJO.JobLine

      OPEN CUR_WOJ

      FETCH NEXT FROM CUR_WOJ INTO @c_WorkOrderKey
                                 , @c_WkOrdReqInputsKey
                                 , @n_UOMQtyJob          
                                 , @n_QtyJob
                                 , @n_QtyCompleted
                                     
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         SET @n_WOUOMQty = 0
         SET @n_WOInputQty = 0
         SELECT @n_WOUOMQty = WORKORDERREQUEST.UOMQty
               ,@n_WOInputQty = WORKORDERREQUESTINPUTS.Qty 
         FROM WORKORDERREQUEST WITH (NOLOCK)
         JOIN WORKORDERREQUESTINPUTS WITH (NOLOCK) ON (WORKORDERREQUEST.WorkOrderkey = WORKORDERREQUESTINPUTS.WorkOrderkey)
         WHERE WORKORDERREQUESTINPUTS.WorkOrderkey = @c_WorkOrderKey
         AND WORKORDERREQUESTINPUTS.WkOrdReqInputsKey = @c_WkOrdReqInputsKey
         AND WORKORDERREQUESTINPUTS.Qty > 0

         IF @n_WOInputQty = 0
         BEGIN
            GOTO NEXT_JOBLINE
         END

         SET @n_BOMQty = 1

         IF @n_WOUOMQty > 0
         BEGIN
            SET @n_BOMQty = @n_WOInputQty / @n_WOUOMQty 
         END

    
         SET @n_QtyComsumed = @n_QtyComsumed + ( CASE WHEN @n_QtyJob = 0 THEN 0 ELSE ( @n_QtyCompleted / @n_QtyJob ) END 
                                                * (@n_BOMQty * @n_UOMQtyJob) )

         NEXT_JOBLINE:
         FETCH NEXT FROM CUR_WOJ INTO @c_WorkOrderKey
                                    , @c_WkOrdReqInputsKey
                                    , @n_UOMQtyJob          
                                    , @n_QtyJob
                                    , @n_QtyCompleted
      END
      CLOSE CUR_WOJ
      DEALLOCATE CUR_WOJ

      SET @n_Discrepancy = 0
      SET @n_Discrepancy = (@n_QtyUncased) - (@n_QtyWastage + @n_QtyReject + @n_QtyRemaining + @n_QtyComsumed) 
      
      SET @c_SkuDescr = ''
 
      IF ISNULL(@c_Sku,'') <> ''
      BEGIN
         SELECT @c_SkuDescr = SKU.Descr
         FROM SKU WITH (NOLOCK) 
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku
      END
      ELSE
      BEGIN
         SELECT @c_SkuDescr = Descr
         FROM NONINV WITH (NOLOCK) 
         WHERE Storerkey = @c_Storerkey
         AND NonInvSku = @c_NonInvSku
      END

      INSERT INTO #TEMP_RECON
            (  JobKey
            ,  SkuType
            ,  Storerkey
            ,  Sku
            ,  NonInvSku
            ,  SkuDescr
            ,  QtyReserved
            ,  QtyUncased
            ,  QtyWastage
            ,  QtyReject
            ,  QtyRemaining
            ,  QtyComsumed
            ,  FGToProduce
            ,  CompletedFG
            ,  Discrepancy
            ,  PalletQty            --(Wan01)
            ) 
      VALUES(  @c_JobKey
            ,  'I'
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @c_NonInvSku
            ,  @c_SkuDescr
        ,  @n_QtyReserved
            ,  @n_QtyUncased
            ,  @n_QtyWastage
            ,  @n_QtyReject
            ,  @n_QtyRemaining
            ,  @n_QtyComsumed
            ,  0
            ,  0
            ,  @n_Discrepancy
            ,  @n_PalletQty         --(Wan01)
            ) 
      FETCH NEXT FROM CUR_RECON INTO  @c_Storerkey
                                    , @c_Sku
                                    , @c_NonInvSku
                                    , @n_QtyReserved
                                    , @n_QtyWastage
                                    , @n_QtyReject
                                    , @n_QtyRemaining
   END
   CLOSE CUR_RECON
   DEALLOCATE CUR_RECON
   -- OUTPUT
   INSERT INTO #TEMP_RECON
         (  JobKey
         ,  SkuType 
         ,  Storerkey
         ,  Sku
         ,  NonInvSku
         ,  SkuDescr
         ,  QtyReserved
         ,  QtyUncased
         ,  QtyWastage
         ,  QtyReject
         ,  QtyRemaining
         ,  QtyComsumed
         ,  FGToProduce
         ,  CompletedFG
         ,  Discrepancy
         ,  PalletQty               --(Wan01)
         ) 
   SELECT   @c_JobKey
         , 'O'
         ,  WORO.Storerkey
         ,  WORO.Sku
         ,  ''
         ,  SKU.Descr
         ,  0
         ,  0
         ,  0
         ,  0
         ,  0
         ,  0
         ,  ISNULL(SUM(WOJ.QtyJob),0) 
         ,  ISNULL(SUM(WOJ.Qtycompleted),0) 
         ,  ISNULL(SUM(WOJ.QtyJob),0) - ISNULL(SUM(WOJ.Qtycompleted),0) 
         ,  0                       --(Wan01)
   FROM WORKORDERJOB            WOJ  WITH (NOLOCK)
   JOIN WORKORDERREQUESTOUTPUTS WORO WITH (NOLOCK) ON (WOJ.Workorderkey = WORO.Workorderkey)
   JOIN SKU WITH (NOLOCK) ON (WORO.Storerkey = SKU.Storerkey)
                          AND(WORO.Sku = SKU.Sku)
   WHERE JobKey = @c_JobKey 
   GROUP BY WORO.Storerkey
         ,  WORO.Sku
         ,  SKU.Descr
      
   SELECT   JobKey
         ,  SkuType
         ,  Storerkey
         ,  Sku
         ,  NonInvSku
         ,  SkuDescr
         ,  QtyReserved
         ,  QtyUncased
         ,  QtyWastage
         ,  QtyReject
         ,  QtyRemaining
         ,  QtyComsumed
         ,  FGToProduce
         ,  CompletedFG
         ,  Discrepancy
         ,  '    ' rowfocusindicatorcol
         ,  PalletQty            --(Wan01)
   FROM #TEMP_RECON 
   ORDER BY SkuType
END

GO