SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_RPT_PACKING_UNPICKLOC_001                         */    
/* Creation Date: 12-JAN-2022                                              */    
/* Copyright: LFL                                                          */    
/* Written by: WZPANG                                                      */    
/*                                                                         */    
/* Purpose: WMS-18730                                                      */    
/*                                                                         */    
/* Called By: RPT_PACKING_UNPICKLOC_001                                    */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date         Author  Ver   Purposes                                     */  
/* 12-Jan-2022  WZPANG  1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_RPT_PACKING_UNPICKLOC_001]
	  @c_Storerkey        NVARCHAR(15),
	  @c_LabelNo		    NVARCHAR(20)
         
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF OBJECT_ID('tempdb..#TMP_PDLOG') IS NOT NULL
      DROP TABLE #TMP_PDLOG
   
   CREATE TABLE #TMP_PDLOG (
      Storerkey         NVARCHAR(15)
    , OrderKey          NVARCHAR(10)
    , Orderlinenumber   NVARCHAR(5)
    , Sku               NVARCHAR(20)
    , Lot               NVARCHAR(20)
    , Loc               NVARCHAR(20)
    , Qty               INT
    , DropID            NVARCHAR(50)
    , CaseID            NVARCHAR(50)
   )

   INSERT INTO #TMP_PDLOG(Storerkey, OrderKey, Orderlinenumber, Sku, Lot, Loc, Qty, DropID, CaseID)
   SELECT TRIM(PICKDET_LOG.StorerKey) AS StorerKey,
          PICKDET_LOG.OrderKey,
          PICKDET_LOG.Orderlinenumber,
          TRIM(PICKDET_LOG.Sku) AS SKU,
          PICKDET_LOG.Lot,
          PICKDET_LOG.Loc,
          PICKDET_LOG.Qty,
          PICKDET_LOG.DropID,
          PICKDET_LOG.CaseID   
   FROM PICKDET_LOG (NOLOCK)
   WHERE PICKDET_LOG.StorerKey = @c_StorerKey
   AND PICKDET_LOG.CaseID = @c_LabelNo
   
   IF NOT EXISTS (SELECT 1 FROM #TMP_PDLOG TP)
   BEGIN
      INSERT INTO #TMP_PDLOG(Storerkey, OrderKey, Orderlinenumber, Sku, Lot, Loc, Qty, DropID, CaseID)
      SELECT TRIM(PICKDET_LOG.StorerKey) AS StorerKey,
             PICKDET_LOG.OrderKey,
             PICKDET_LOG.Orderlinenumber,
             TRIM(PICKDET_LOG.Sku) AS SKU,
             PICKDET_LOG.Lot,
             PICKDET_LOG.Loc,
             PICKDET_LOG.Qty,
             PICKDET_LOG.DropID,
             PICKDET_LOG.CaseID    
      FROM PICKDET_LOG (NOLOCK)
      WHERE PICKDET_LOG.StorerKey = @c_StorerKey
      AND PICKDET_LOG.DropID = @c_LabelNo
   END

   SELECT TP.Storerkey      
        , TP.OrderKey       
        , TP.Orderlinenumber
        , TP.Sku            
        , TP.Lot            
        , TP.Loc            
        , TP.Qty            
        , TP.DropID         
        , TP.CaseID         
   FROM #TMP_PDLOG TP
   ORDER BY TP.OrderKey
          , TP.OrderLineNumber
          , TP.Sku

END

GO