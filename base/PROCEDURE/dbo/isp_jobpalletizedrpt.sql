SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Function: isp_JobPalletizedRpt                                             */    
/* Creation Date: 08-OCT-2015                                                 */    
/* Copyright: LFL                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose: SOS#317743 - Project Merlion VAP Print Uncasing and Palletizing   */    
/*        : Sheet                                                             */    
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
/* Called By: Exceed Job Maintenance                                          */    
/*                                                                            */    
/* PVCS Version: 1.0                                                          */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    
CREATE PROC [dbo].[isp_JobPalletizedRpt]
(  @c_JobKey      NVARCHAR(10)
) 
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_WorkOrderkey       NVARCHAR(30)
         , @c_MasterWorkOrder    NVARCHAR(50)
         , @c_ExternalReference  NVARCHAR(30)
         , @c_Udf1               NVARCHAR(20) 
         , @c_Udf3               NVARCHAR(20) 
         , @c_Udf4               NVARCHAR(20)
         , @c_o_Storerkey        NVARCHAR(15)
         , @c_o_Sku              NVARCHAR(20)
         , @c_o_Skudescr         NVARCHAR(60)
         , @c_o_busr7            NVARCHAR(30)
         , @c_interimstorer      NVARCHAR(15)
         , @c_interimsku         NVARCHAR(20)
         , @n_QtyJob             INT
         , @n_QtyWO              INT

   CREATE TABLE #TEMP_WOPALLETIZED
      (  Jobkey            NVARCHAR(10)   NULL  DEFAULT('')
      ,  WorkOrderkey      NVARCHAR(10)   NULL  DEFAULT('') 
      ,  MasterWorkOrder   NVARCHAR(50)   NULL  DEFAULT('')  
      ,  ExternalReference NVARCHAR(30)   NULL  DEFAULT('')   
      ,  Udf1              NVARCHAR(20)   NULL  DEFAULT('') 
      ,  Udf3              NVARCHAR(20)   NULL  DEFAULT('')
      ,  Udf4              NVARCHAR(20)   NULL  DEFAULT('')
      ,  QtyJob            INT            NULL  DEFAULT(0)
      ,  QtyWO             INT            NULL  DEFAULT(0)
      ,  O_Storerkey       NVARCHAR(15)   NULL  DEFAULT('') 
      ,  O_Sku             NVARCHAR(20)   NULL  DEFAULT('') 
      ,  O_SkuDescr        NVARCHAR(60)   NULL  DEFAULT('')
      ,  O_BUSR7           NVARCHAR(30)   NULL  DEFAULT('')
      ,  InterimStorer     NVARCHAR(15)   NULL  DEFAULT('') 
      ,  InterimSku        NVARCHAR(20)   NULL  DEFAULT('') 
      ,  PalletID          NVARCHAR(18)   NULL  DEFAULT('')
      ,  Qty               INT            NULL  DEFAULT(0)
      ,  StartDate         DATETIME       NULL
      ,  EndDate           DATETIME       NULL
      ,  Lottable01        NVARCHAR(18)   NULL  DEFAULT('') 
      ,  Lottable02        NVARCHAR(18)   NULL  DEFAULT('') 
      ,  Lottable03        NVARCHAR(18)   NULL  DEFAULT('') 
      ,  Lottable04        DATETIME       NULL  
      ) 

   DECLARE CUR_WO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT WorkOrderkey
         ,QtyJob
   FROM WORKORDERJOB WITH (NOLOCK)
   WHERE JobKey = @c_JobKey

   OPEN CUR_WO

   FETCH NEXT FROM CUR_WO INTO @c_WorkOrderkey
                              ,@n_QtyJob
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @c_MasterWorkOrder = ''
      SET @c_ExternalReference = ''
      SET @c_Udf1 = ''
      SET @c_Udf3 = ''
      SET @c_Udf4 = ''
      SET @n_QtyWO= 0
      SELECT  @c_MasterWorkOrder = MasterWorkOrder 
            , @c_ExternalReference = ExternalReference     
            , @c_Udf1 = Udf1              
            , @c_Udf3 = Udf3 
            , @c_Udf4 = Udf4 
            , @n_QtyWO= Qty            
      FROM WORKORDERREQUEST WITH (NOLOCK)
      WHERE WorkOrderkey = @c_WorkOrderkey

      SET @c_o_Storerkey = ''
      SET @c_o_Sku         = ''
      SET @c_o_Skudescr    = ''
      SET @c_o_busr7       = ''
      SET @c_interimstorer = ''
      SET @c_interimsku    = ''
      SELECT @c_o_Storerkey= SKU.Storerkey
            ,@c_o_Sku      = SKU.Sku
            ,@c_o_Skudescr = SKU.Descr
            ,@c_o_busr7    = SKU.Busr7
            ,@c_interimstorer = WORKORDERREQUESTOUTPUTS.PrimaryStorer
            ,@c_interimsku    = WORKORDERREQUESTOUTPUTS.Sku
      FROM WORKORDERREQUESTOUTPUTS WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (WORKORDERREQUESTOUTPUTS.Storerkey = SKU.Storerkey)
                             AND(WORKORDERREQUESTOUTPUTS.Sku = SKU.Sku)
      WHERE WORKORDERREQUESTOUTPUTS.WorkOrderkey = @c_Workorderkey

      INSERT INTO #TEMP_WOPALLETIZED
            (  JobKey
            ,  WorkOrderkey
            ,  MasterWorkOrder
            ,  ExternalReference       
            ,  Udf1  
            ,  Udf3        
            ,  Udf4
            ,  QtyJob
            ,  QtyWO
            ,  o_Storerkey     
            ,  o_Sku  
            ,  o_SkuDescr  
            ,  o_busr7
            ,  InterimStorer     
            ,  InterimSku           
            ,  PalletID
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  StartDate 
            ,  EndDate 
            ,  Qty  
            )
      SELECT   @c_JobKey
            ,  @c_WorkOrderkey 
            ,  @c_MasterWorkOrder
            ,  @c_ExternalReference      
            ,  @c_Udf1
            ,  @c_Udf3          
            ,  @c_Udf4   
            ,  @n_QtyJob
            ,  @n_QtyWO
            ,  @c_o_Storerkey     
            ,  @c_o_Sku
            ,  @c_o_SkuDescr  
            ,  @c_o_busr7              
            ,  @c_interimstorer     
            ,  @c_interimsku      
            ,  ID
            ,  ISNULL(Lottable01,'')
            ,  ISNULL(Lottable02,'')
            ,  ISNULL(Lottable03,'')
            ,  Lottable04
            ,  StartDate 
            ,  EndDate 
            ,  Qty = SUM(Qty)
      FROM WORKORDER_PALLETIZE WITH (NOLOCK)
      WHERE JobKey = @c_JobKey
      AND   WorkOrderkey = @c_Workorderkey
      GROUP BY ID
            ,  ISNULL(Lottable01,'')
            ,  ISNULL(Lottable02,'')
            ,  ISNULL(Lottable03,'')
            ,  Lottable04
            ,  StartDate 
            ,  EndDate 

      FETCH NEXT FROM CUR_WO INTO @c_WorkOrderkey
                                 ,@n_QtyJob
   END
   CLOSE CUR_WO
   DEALLOCATE CUR_WO

   SELECT   JobKey
         ,  WorkOrderkey
         ,  MasterWorkOrder  
         ,  ExternalReference      
         ,  Udf1          
         ,  Udf3 
         ,  Udf4 
         ,  QtyJob 
         ,  QtyWO 
         ,  o_Storerkey     
         ,  o_Sku
         ,  o_SkuDescr  
         ,  o_busr7              
         ,  InterimStorer     
         ,  InterimSku      
         ,  No = (Row_Number() OVER (PARTITION BY JobKey, WorkOrderkey ORDER BY JobKey, WorkOrderkey, StartDate, EndDate, PalletID))
         ,  PalletID
         ,  Qty
         ,  StartDate 
         ,  EndDate 
         ,  Lottable01 = ISNULL(Lottable01,'')
         ,  Lottable02 = ISNULL(Lottable02,'')
         ,  Lottable03 = ISNULL(Lottable03,'')
         ,  Lottable04
   FROM #TEMP_WOPALLETIZED
END

GO