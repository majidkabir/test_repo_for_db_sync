SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_AdidasSetupPickface                            */    
/* Copyright: IDS                                                       */    
/* Written by: TLTING                                                   */    
/* Purpose: generate adidas pickface                                    */    
/* Called By: BEJ - Check Up KPI                                        */    
/* Updates:                                                             */    
/* Date        Author   ver   Purposes                                  */    
/* 01-Jun-2022 TLTING   1.0   Initial version                           */     
/* 09-Jan-2023 TLTING01 1.1   WMS-21427                                 */   
/************************************************************************/    
CREATE    PROC [dbo].[isp_AdidasSetupPickface]      
@c_storerkey NVARCHAR(15) ,  
@c_facility NVARCHAR(5)  
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
   SET ANSI_NULLS OFF       
      
   DECLARE   @cExecStatements    NVARCHAR(4000)      
            ,@cExecArguments     NVARCHAR(4000)      
            ,@n_debug            INT     
            ,@n_Err              INT            --KH01    
            ,@c_ErrMsg           NVARCHAR(255)  --KH01    
            ,@c_AlertKey         char(18)       --KH01    
            ,@dBegin             DATETIME       --KH01    
            ,@nErrSeverity       INT            --KH01    
            ,@nErrState          INT            --KH01    
  
   DECLARE @c_SKU    NVARCHAR(20)  
   DECLARE @c_LOC    NVARCHAR(10)  
   DECLARE @c_PickFace    NVARCHAR(10)  
  
   SET @c_PickFace = 'PICK'   
   SET @n_debug   = 0      
  
   CREATE TABLE #SKUList
   ( rowref INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
   SKU NVARCHAR(20) NOT NULL
   
   )

   --SELECT  SKU   
   --INTO #SKUList  
   --FROM UCC (NOLOCK)   
   --WHERE storerkey = @c_storerkey   
   --AND status IN ('0','1','3')  

   INSERT INTO #SKUList ( SKU )                     
   select  sku 
   FROM LotxLocxId LT (nolock) 
   JOIN loc L (nolock) on LT.loc=L.Loc
   where LT.storerkey = @c_storerkey 
   AND L.LocationType = 'DPBULK'
   AND LT.Qty > 0
   UNION
   select  sku 
   FROM UCC (nolock)
   where storerkey = @c_storerkey
   AND status IN ('1','3','5')


   DECLARE CUR_ItemCand CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT SKU,  LOC   
   FROM SKUxLoc (NOLOCK)   
   WHERE storerkey = @c_storerkey   
   AND QTY = 0   
   AND LocationType = @c_PickFace  
   AND LOC LIKE 'HLV%'    
   AND NOT EXISTS ( SELECT 1 FROM #SKUList A WHERE A.SKU = SKUxLoc.SKU )  
   AND EXISTS ( SELECT 1 FROM LOC WHERE LOC.LOC = SKUxLoc.LOC AND LOC.facility = @c_facility )  
         
   OPEN CUR_ItemCand      
         
   FETCH NEXT FROM CUR_ItemCand INTO @c_SKU, @c_LOC       
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
        
      DELETE dbo.SKUxLoc WITH (ROWLOCK) WHERE storerkey = @c_storerkey AND SKU = @c_SKU AND LOC = @c_LOC  
            
      FETCH NEXT FROM CUR_ItemCand INTO @c_SKU, @c_LOC       
   END      
   CLOSE CUR_ItemCand      
   DEALLOCATE CUR_ItemCand       
     
   DROP TABLE #SKUList  
  
   SELECT ROW_NUMBER() OVER (ORDER BY loc ) row_num, loc   
   INTO #LOC_Cand  
   FROM LOC (NOLOCK)   
   WHERE LOC LIKE 'HLV%'   
   AND facility = @c_facility  
   AND NOT EXISTS ( SELECT 1 FROM SKUxLoc A (NOLOCK)   
                     WHERE A.storerkey = @c_storerkey    
                     AND  A.LOC = LOC.LOC AND LocationType = @c_PickFace   )  
                        
   --SELECT ROW_NUMBER() OVER (ORDER BY SKU ) row_num, SKU   
   --INTO #SKU_Cand  
   --FROM UCC (NOLOCK)   
   --WHERE storerkey = @c_storerkey   
   --AND status IN ('0','1','3')  
   --AND NOT EXISTS ( SELECT 1 FROM SKUxLoc A (NOLOCK)   
   --               WHERE A.storerkey = UCC.storerkey    
   --               AND  A.SKU = UCC.SKU AND LocationType = @c_PickFace  )  
   --GROUP BY SKU  
   --ORDER BY SKU  

    SELECT ROW_NUMBER() OVER (ORDER BY SKU ) row_num, SKU   
   INTO #SKU_Cand     
   FROM ( SELECT  sku 
         FROM LotxLocxId LT (nolock) 
         JOIN loc L (nolock) on LT.loc=L.Loc
         where LT.storerkey = @c_storerkey 
         AND L.LocationType = 'DPBULK'
         AND LT.Qty > 0
         AND NOT EXISTS ( SELECT 1 FROM SKUxLoc A (NOLOCK)   
                        WHERE A.storerkey = LT.storerkey    
                        AND  A.SKU = LT.SKU  AND LocationType = @c_PickFace )  
         UNION
         SELECT  sku 
         FROM UCC (nolock)
         where storerkey = @c_storerkey
         AND status IN ('1','3','5')
         AND NOT EXISTS ( SELECT 1 FROM SKUxLoc A (NOLOCK)   
                        WHERE A.storerkey = UCC.storerkey    
                        AND  A.SKU = UCC.SKU AND LocationType = @c_PickFace  )  
         GROUP BY SKU              ) AS A
   
  

    INSERT INTO SKUXLOC (StorerKey  
         , Sku  
         , Loc  
         , QtyLocationLimit  
         , QtyLocationMinimum  
         , LocationType)     
    SELECT @c_storerkey  
         , A.Sku  
         , B.Loc  
         , 0  
         , 0  
         , @c_PickFace  
   FROM #SKU_Cand A, #LOC_Cand B  
   WHERE A.row_num = B.row_num  
     
   DROP TABLE #SKU_Cand  
   DROP TABLE #LOC_Cand  
END      


GO