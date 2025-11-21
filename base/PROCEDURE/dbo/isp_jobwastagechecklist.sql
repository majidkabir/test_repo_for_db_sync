SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Function: isp_JobWastageChecklist                                          */    
/* Creation Date: 07-OCT-2015                                                 */    
/* Copyright: LFL                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose:                                                                   */    
/*                                                                            */    
/* Input Parameters:@c_JobKey                                                 */    
/*                 :@c_WorkOrderkey                                           */    
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
/* PVCS Version: 1.13                                                         */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    
CREATE PROC [dbo].[isp_JobWastageChecklist]
(  @c_JobKey         NVARCHAR(10)
,  @c_WorkOrderkey   NVARCHAR(10)
) 
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_JobInputSkuList NVARCHAR(255)
         , @c_Sku             NVARCHAR(20)
 
   SET @c_JobInputSkuList = ''

--   DECLARE CUR_INPUT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
--   SELECT Sku
--   FROM WORKORDERREQUESTSINPUT WITH (NOLOCK)
--   WHERE WorkOrderkey = @c_WorkOrderKey
--
--   OPEN CUR_INPUT
--
--   FETCH NEXT FROM CUR_INPUT INTO @c_Sku
-- 
--   WHILE @@FETCH_STATUS <> -1  
--   BEGIN
--      SET @c_JobInputSkuList = @c_JobInputSkuList + @c_Sku + ', '
--      FETCH NEXT FROM CUR_INPUT INTO @c_Sku
--   END
--   CLOSE CUR_INPUT
--   DEALLOCATE CUR_INPUT
--
--   IF RIGHT( @c_JobInputSkuList,2 ) = ', '
--   BEGIN
--      SET @c_JobInputSkuList = SUBSTRING(@c_JobInputSkuList, 1, LEN(@c_JobInputSkuList) - 2 )
--   END

   SELECT   WORKORDERJOB.JobKey 
         ,  WORKORDERREQUEST.ExternalReference
         ,  WORKORDERJOB.WorkOrderkey
         ,  WORKORDERREQUEST.Qty
         ,  WORKORDERREQUEST.Udf1
         ,  SKU.Sku
         ,  SKU.Descr
   FROM WORKORDERJOB     WITH (NOLOCK)
   JOIN WORKORDERREQUEST WITH (NOLOCK) ON (WORKORDERJOB.WorkOrderkey = WORKORDERREQUEST.WorkOrderkey)
   JOIN WORKORDERREQUESTOUTPUTS WITH (NOLOCK) ON (WORKORDERREQUEST.WorkOrderkey = WORKORDERREQUESTOUTPUTS.WorkOrderkey)
   JOIN SKU              WITH (NOLOCK) ON (WORKORDERREQUESTOUTPUTS.Storerkey = SKU.Storerkey)
                                       AND(WORKORDERREQUESTOUTPUTS.Sku = SKU.Sku)
   WHERE WORKORDERJOB.JobKey = @c_JobKey
   AND   WORKORDERJOB.WorkOrderkey = @c_WorkOrderkey

END

GO