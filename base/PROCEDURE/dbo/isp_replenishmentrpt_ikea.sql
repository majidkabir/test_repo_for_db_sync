SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/              
/* Stored Proc: isp_ReplenishmentRpt_ikea                                  */              
/* Creation Date: 27-DEC-2019                                              */              
/* Copyright: LF Logistics                                                 */              
/* Written by: CSCHONG                                                     */              
/*                                                                         */              
/* Purpose:WMS-11473-[CN] IKEA_ECOM_Replenishemnt Report                   */              
/*        :                                                                */              
/* Called By: r_replenishmentrpt_ikea                                      */              
/*          :                                                              */              
/* PVCS Version: 1.0                                                       */              
/*                                                                         */              
/* Data Modifications:                                                     */              
/*                                                                         */              
/* Updates:                                                                */              
/* Date         Author     Ver  Purposes                                   */             
/* 12-JUN-2020  CSCHONG    1.1  WMS-12743 - revised field mapping (CS01)   */    
/* 29-SEP-2020  KuanYee    1.2  INC1308712 - Add quotation marks  (KY01)   */  
/***************************************************************************/              
CREATE PROC [dbo].[isp_ReplenishmentRpt_ikea]              
           @c_storerKey       NVARCHAR(10),              
           @c_facility        NVARCHAR(10),    
           @c_Area            NVARCHAR(10) = ''              
              
AS              
BEGIN              
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF          
              
   DECLARE                
           @n_StartTCnt         INT              
         , @n_Continue          INT              
         , @n_NoOfLine          INT              
         , @c_arcdbname         NVARCHAR(50)              
         , @c_lot               NVARCHAR(50)              
         , @n_Pcs               INT              
         , @n_OriSalesPrice     FLOAT              
         , @n_ARHOriSalesPrice  FLOAT              
         , @c_reasoncode        NVARCHAR(45)              
         , @c_codedescr         NVARCHAR(120)              
         , @c_lottable02        NVARCHAR(20)              
         , @c_polott02          NVARCHAR(20)              
         , @c_Sql               NVARCHAR(MAX)              
         , @c_SqlParms          NVARCHAR(4000)              
         , @c_DataMartServerDB  NVARCHAR(120)              
         , @sql                 NVARCHAR(MAX)              
         , @sqlinsert           NVARCHAR(MAX)              
         , @sqlselect           NVARCHAR(MAX)              
         , @sqlfrom             NVARCHAR(MAX)              
         , @sqlwhere            NVARCHAR(MAX)          
         , @c_SQLSelect         NVARCHAR(4000)              
         , @n_Uprice            FLOAT              
         , @n_GTPcs             INT              
         , @n_GTPLOT            FLOAT        
         , @n_cntsku            INT --CS01          
         , @c_unit              NVARCHAR(5)  --CS01    
              
   SET @n_StartTCnt = @@TRANCOUNT              
                 
   SET @n_NoOfLine = 13                      
                 
   DECLARE @n_Status      NVARCHAR(10),      
           @n_Qty         INT,      
           @n_QtyReplen   INT,      
           @n_QtyPickLoc  INT,      
           @n_MaxRowID    INT,      
           @n_QtyCandi    INT,      
           @n_QtyUnReplen INT,      
           @c_PickLoc    NVARCHAR(10),      
           @n_BulkQty     INT,    
           @n_cntID       INT,             --CS01      
           @n_cntTTLID    INT,             --CS01      
           @c_lliloc      NVARCHAR(10),    --CS01    
 @c_SIExtField01 NVARCHAR(30),   --CS01       
           @c_SIExtField02 NVARCHAR(30),   --CS01    
           @c_SIExtField03 NVARCHAR(30),   --CS01     
           @c_SIExtfield   NVARCHAR(30)      --CS01     
           
   DECLARE @i INT      
           
   DECLARE @c_SKU NVARCHAR(20),      
           @c_QtyOrdered INT,      
           @c_QtyReplen  INT,      
           @c_QryUnReplen INT      
          
   SET @n_Status = '0'      
   SET @n_Qty = 0      
   SET @n_QtyReplen = 0      
   SET @n_QtyPickLoc = 0      
   SET @n_MaxRowID = 0      
   SET @n_QtyCandi = 0      
   SET @n_QtyUnReplen = 0      
   SET @c_PickLoc = ''      
   SET @n_BulkQty = 0      
   SET @c_unit   = N'托'          --CS01    
   SET @c_SIExtfield = ''         --CS01    
         
   SET @c_facility = UPPER(@c_facility) -- stvl hyperion case sensitive simple link      
      
   CREATE TABLE #Open_Qty (SKU        NVARCHAR(20),      
                           QtyOrdered INT,      
                           QtyReplen  INT)      
              
   CREATE TABLE #Temp_BulkInv (RowID     INT,      
                              SKU        NVARCHAR(20),      
                              ID         NVARCHAR(30),      
                              CaseCnt    INT,      
                              Qty        INT,      
                              LOC        NVARCHAR(10),      
                              LogicalLOC NVARCHAR(10),      
                              Lottable04 NVARCHAR(10),    
                              SSUSR3     NVARCHAR(18)      
         )      
              
   CREATE TABLE #Temp_Result (Facility   NVARCHAR(10),      
                              SKU        NVARCHAR(20),      
                              CaseCnt    INT,      
                              ID         NVARCHAR(30),      
                              QtyReplen  INT,      
                              CaseReplen INT,      
                              BulkLoc    NVARCHAR(10),      
                              BulkQty    INT,      
                              PickLoc    NVARCHAR(10),    
                              SSUSR3     NVARCHAR(18),    
                              CntID      INT,    
                              SIExtfield NVARCHAR(20)                           --CS01       
         )      
      
   INSERT INTO #Open_Qty      
                        (      
                         SKU,      
                         QtyOrdered,      
                         QtyReplen      
                        )      
   SELECT od.Sku,SUM(od.OriginalQty), 0      
   FROM  ORDERS o WITH(NOLOCK)       
   JOIN  ORDERDETAIL od WITH (NOLOCK) ON od.OrderKey = o.OrderKey      
   WHERE o.StorerKey = @c_StorerKey AND o.[Status] = @n_Status AND o.Facility = @c_facility      
   AND o.doctype='E'                                      --CS01     
   GROUP BY od.Sku      
         
   DECLARE my_cur CURSOR FAST_FORWARD READ_ONLY FOR      
   SELECT SKU,QtyOrdered      
   FROM #Open_Qty      
   OPEN my_cur FETCH NEXT FROM my_cur INTO @c_SKU,@c_QtyOrdered      
   WHILE @@FETCH_STATUS <> -1      
       
   BEGIN      
        
     SET @n_QtyPickLoc = 0      
        
     --SELECT @n_QtyPickLoc = ISNULL( SUM(lli.Qty) ,0)     --CS01    
     SELECT @n_QtyPickLoc = ISNULL( SUM(lli.Qty-lli.QtyAllocated-QtyPicked) ,0)    
     FROM  LOTxLOCxID lli WITH (NOLOCK)      
     JOIN  LOC l WITH (NOLOCK) ON l.Loc = lli.Loc      
     WHERE l.Facility = @c_facility AND l.LocationType = 'PICK' AND lli.StorerKey = @c_StorerKey      
     AND lli.Sku = @c_SKU      
        
     UPDATE #Open_Qty     
     SET QtyReplen =   @c_QtyOrdered - @n_QtyPickLoc    --CS01    
     WHERE SKU = @c_SKU      
        
   FETCH NEXT FROM my_cur INTO @c_SKU,@c_QtyOrdered      
   END      
   CLOSE my_cur      
   DEALLOCATE my_cur      
         
   INSERT INTO #Temp_BulkInv (RowID,      
                              SKU ,      
                              ID  ,      
                              CaseCnt ,      
                              Qty ,      
                              LOC ,      
                              LogicalLOC ,      
                              Lottable04,    
                              SSUSR3      
                              )      
   SELECT ROW_NUMBER() OVER (PARTITION BY lli.sku  ORDER BY lot.lottable04 )       
   ,lli.Sku,lli.Id,lot.lottable03,SUM(lli.Qty),lli.loc,l.LogicalLocation,lot.Lottable04,s.susr3      
   FROM #Open_Qty #O WITH (NOLOCK)       
   JOIN  LOTxLOCxID lli WITH (NOLOCK) ON #O.SKU = lli.Sku AND lli.StorerKey = @c_StorerKey      
   JOIN  LOC l WITH (NOLOCK) ON lli.Loc = l.Loc AND l.Facility = @c_facility      
   JOIN  LOTATTRIBUTE lot WITH (NOLOCK) ON lot.Lot = lli.Lot      
   JOIN SKU S WITH (NOLOCK) ON S.SKU=lli.Sku AND s.StorerKey = @c_StorerKey      
   WHERE #O.QtyReplen > 0 AND l.LocationType = 'other' AND l.LocationFlag='none' AND l.LocationCategory='other' AND lli.Qty > 0  --CS01    
   AND lli.loc like CASE WHEN ISNULL(@c_area,'') <> '' THEN @c_area+'%' ELSE lli.loc END                     --CS01    
   GROUP BY lli.Sku,lli.Id,lot.lottable03,lli.loc,l.LogicalLocation,l.Loc,lot.Lottable04,s.susr3     
      
  --select * from #Open_Qty    
  -- select * from #Temp_BulkInv    
    
   DECLARE rpl_cur CURSOR FAST_FORWARD READ_ONLY FOR      
   SELECT SKU,QtyReplen      
   FROM #Open_Qty      
   WHERE QtyReplen> 0      
         
   OPEN rpl_cur FETCH NEXT FROM rpl_cur INTO @c_SKU,@c_QtyReplen      
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
        
  SET @i = 1       
  SET @n_QtyUnReplen = 0      
  SET @n_MaxRowID = 0      
       
        
  SELECT @n_MaxRowID = MAX(RowID)      
  FROM #Temp_BulkInv WHERE SKU = @c_SKU      
        
        
  SELECT @n_QtyUnReplen = @c_QtyReplen      
        
  WHILE @i <= @n_MaxRowID AND @n_QtyUnReplen > 0      
        
   BEGIN      
          
    SELECT TOP 1 @n_QtyCandi = Qty      
    FROM #Temp_BulkInv WHERE SKU = @c_SKU AND RowID = @i      
    ORDER BY RowID, LogicalLOC,LOC      
          
    --SELECT TOP 1 @c_PickLoc = sl.Loc      
    --FROM  SKUxLOC sl WITH (NOLOCK)      
    --JOIN  LOC l WITH (NOLOCK) ON l.Loc = sl.Loc      
    --WHERE l.Facility = @c_facility AND sl.Sku = @c_SKU AND l.LocationType = 'PICK'      
    --ORDER BY sl.Qty ASC      
    
    SELECT TOP 1 @c_PickLoc = lli.loc     
    FROM  LOTxLOCxID lli WITH (NOLOCK)      
    JOIN  LOC l WITH (NOLOCK) ON l.Loc = lli.Loc      
    WHERE l.Facility = @c_facility AND l.LocationType = 'PICK' AND lli.StorerKey = @c_StorerKey      
    AND lli.Sku = @c_SKU  and RIGHT(lli.Loc,1) = '1'          --CS01    
    GROUP BY lli.loc     
    order by ISNULL( SUM(lli.Qty-lli.QtyAllocated-lli.QtyPicked) ,0)  desc   --CS01    
          
    --IF ISNULL(@c_PickLoc ,'') = ''      
    -- BEGIN      
    --  SELECT TOP 1 @c_PickLoc = Loc      
    --  FROM  LOC WITH (NOLOCK) WHERE Facility = @c_facility AND LocationType = 'PICK'      
    -- END     
        
    --CS01 START    
    
     SET @n_cntID = 0    
     SET @c_lliloc = ''    
     SET @n_cntTTLID = 0    
    
     SELECT @c_lliloc = loc    
     FROM #Temp_BulkInv      
     WHERE SKU = @c_SKU AND RowID = @i      
    
     SELECT @n_cntID = COUNT(DISTINCT lli.ID)    
     FROM  LOTxLOCxID lli WITH (NOLOCK)      
     WHERE lli.Sku = @c_SKU and lli.loc=@c_lliloc    
    
     SELECT @n_cntTTLID = COUNT(DISTINCT lli.ID)    
     FROM  LOTxLOCxID lli WITH (NOLOCK)      
     WHERE lli.Sku = @c_SKU    
    
     IF @n_cntID = 1     
     BEGIN    
         IF RIGHT(@c_PickLoc,1) <> '1'   --KY01   
         BEGIN    
           SET @c_PickLoc = ''    
         END         
     END    
    
     SET @c_SIExtfield = ''    
     SET @c_SIExtField01 = ''    
     SET @c_SIExtField02 = ''    
     SET @c_SIExtField03 = ''    
    
    
     SELECT @c_SIExtField01 = SI.ExtendedField01    
           ,@c_SIExtField02 = SI.ExtendedField02    
  ,@c_SIExtField03 = SI.ExtendedField03     
     FROM SKUINFO SI WITH (NOLOCK)    
     WHERE SI.storerkey = @c_storerKey    
     AND SI.sku = @c_SKU    
    
     IF @c_facility = 'KSE01'    
     BEGIN    
        SET @c_SIExtfield = @c_SIExtField01    
     END    
     ELSE  IF @c_facility = 'BJE01'    
     BEGIN    
        SET @c_SIExtfield = @c_SIExtField02    
     END    
     ELSE  IF @c_facility = 'GIK01'    
     BEGIN    
        SET @c_SIExtfield = @c_SIExtField03    
     END    
    
    --CS01 END     
          
    IF @n_QtyCandi > @c_QtyReplen        
    BEGIN      
    
      INSERT INTO #Temp_Result       
                              (Facility,      
              SKU,      
                               CaseCnt,      
                               ID,      
                               QtyReplen,      
                               CaseReplen,      
                               BulkLoc,      
                               BulkQty,      
                               PickLoc,SSUSR3,    
                               CntID,SIExtfield)                  --CS01      
      SELECT  @c_facility,SKU,CaseCnt,ID      
            , @c_QtyReplen--CEILING(@c_QtyReplen * 1.0 / CaseCnt ) * CaseCnt      
            , @c_QtyReplen--CEILING(@c_QtyReplen * 1.0 / CaseCnt )       
            , LOC      
            , @n_QtyCandi--@n_BulkQty      
            , @c_PickLoc     
            , SSUSR3     
            , @n_cntID                 --CS01    
            , @c_SIExtfield            --CS01    
      FROM #Temp_BulkInv      
      WHERE SKU = @c_SKU AND RowID = @i      
            
      SET @n_QtyUnReplen = @n_QtyUnReplen - @n_QtyCandi      
      BREAK          
     END       
     ELSE         
     BEGIN        
     INSERT INTO #Temp_Result       
                              (Facility,      
                               SKU,      
                               CaseCnt,      
                               ID,      
                               QtyReplen,      
                               CaseReplen,      
                               BulkLoc,      
                               BulkQty,      
                               PickLoc,SSUSR3,    
                               CntID,SIExtfield)       --CS01    
      SELECT @c_facility,SKU,CaseCnt,ID      
            , Qty--CEILING(Qty * 1.0 / CaseCnt ) * CaseCnt      
            , Qty--CEILING(Qty * 1.0 / CaseCnt )       
            , LOC      
            , @n_QtyCandi--@n_BulkQty      
            , @c_PickLoc    
            , SSUSR3     
            , @n_cntID,@c_SIExtfield                   --CS01     
      FROM #Temp_BulkInv      
      WHERE SKU = @c_SKU AND RowID = @i      
         
      SET @i = @i + 1      
      SET @n_QtyUnReplen = @n_QtyUnReplen - @n_QtyCandi            
     END             
   END      
    
      --CS01 START    
         SET @n_cntsku = 1    
    
         SELECT @n_cntsku = COUNT(1)    
         FROM #Temp_Result    
         WHERE sku = @c_sku     
    
         IF @n_cntsku > 1    
         BEGIN    
          SET @c_PickLoc = N'虚拟库位'    
    
          UPDATE #Temp_Result    
          SET PickLoc = @c_PickLoc    
          WHERE sku = @c_SKU     
         END       
            
      --CS01 END    
        
   FETCH NEXT FROM rpl_cur INTO @c_SKU,@c_QtyReplen      
   END      
   CLOSE rpl_cur      
   DEALLOCATE rpl_cur      
    
   SELECT SKU as grpsku,     
          CASE WHEN CAST(COUNT(DISTINCT ID) AS NVARCHAR(5)) > 1 THEN CAST(COUNT(DISTINCT ID) AS NVARCHAR(5)) + @c_unit ELSE '' END as cntgrp    
   INTO #Temp_GrpResult    
   FROM #Temp_Result    
   GROUP BY SKU    
   --HAVING CAST(COUNT(DISTINCT ID) AS NVARCHAR(5)) > 1     
    
      
   SELECT DISTINCT #Temp_Result.SKU,      
          #Temp_Result.CaseCnt,      
          #Temp_Result.ID,      
          #Temp_Result.QtyReplen,      
          #Temp_Result.CaseReplen,      
          #Temp_Result.BulkLoc,      
          #Temp_Result.BulkQty,      
          CASE WHEN #Temp_Result.QtyReplen = 0 THEN '' ELSE #Temp_Result.PickLoc END AS PickLoc,    
          (Row_Number() OVER (ORDER BY #Temp_Result.BulkLoc Asc)-1)/@n_NoOfLine as recgrp     
          ,#Temp_Result.SSUSR3    
          ,#Temp_GrpResult.cntgrp as CNT--CASE WHEN CntID> 1 THEN CONVERT( NVARCHAR(5),CntID) + @c_unit ELSE '' END AS CNT   --CS01    
          ,#Temp_Result.SIExtfield                   --CS01    
   FROM #Temp_Result              
   JOIN #Temp_GrpResult ON #Temp_GrpResult.grpsku = #Temp_Result.sku    
   order by  #Temp_Result.BulkLoc                --CS01    
                       
END -- procedure     

GO