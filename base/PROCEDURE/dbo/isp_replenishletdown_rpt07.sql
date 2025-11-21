SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReplenishLetdown_rpt07                              */
/* Creation Date: 01-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1242 - CN Skecher's Rlenishment Report Request          */
/*        :                                                             */
/* Called By:  r_dw_replenishletdown_rpt07                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ReplenishLetdown_Rpt07]
            @c_Storerkey    NVARCHAR(15)
          , @c_Facility     NVARCHAR(5)
          , @c_LoadKeyStart NVARCHAR(10)
          , @c_LoadKeyEnd   NVARCHAR(10)  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt    INT
         , @c_Orderkey     NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   
   -- CREATE TEMP TABLE #TMP_PICK
   CREATE TABLE #TMP_PICK
   (  Storerkey            NVARCHAR(15)   NULL DEFAULT('')
   ,  Sku                  NVARCHAR(20)   NULL DEFAULT('')
   ,  Lot                  NVARCHAR(10)   NULL DEFAULT('')
   ,  Loc                  NVARCHAR(10)   NULL DEFAULT('')
   ,  ID                   NVARCHAR(18)   NULL DEFAULT('')
   ,  QtyPicked            INT            NULL DEFAULT(0)
   )

   CREATE INDEX IDX_PICK ON #TMP_PICK( Lot, Loc, ID ) 

   CREATE TABLE #TMP_REPL
   (  Storerkey            NVARCHAR(15)   NULL DEFAULT('')
   ,  Sku                  NVARCHAR(20)   NULL DEFAULT('')
   ,  Lot                  NVARCHAR(10)   NULL DEFAULT('')
   ,  Loc                  NVARCHAR(10)   NULL DEFAULT('')
   ,  ID                   NVARCHAR(18)   NULL DEFAULT('')
   ,  ToLoc                NVARCHAR(10)   NULL DEFAULT('')
   ,  QtyReplen            INT            NULL DEFAULT(0)
   )
   
   CREATE TABLE #TMP_LLI
      (  Storerkey            NVARCHAR(15)   NULL DEFAULT('')
      ,  Sku                  NVARCHAR(20)   NULL DEFAULT('')
      ,  Lot                  NVARCHAR(10)   NULL DEFAULT('')
      ,  Loc                  NVARCHAR(10)   NULL DEFAULT('')
      ,  ID                   NVARCHAR(18)   NULL DEFAULT(0)
      ,  QtyAvail             INT            NULL DEFAULT('')
      ,  Packkey              NVARCHAR(10)   NULL DEFAULT('')
      ,  CaseCnt              FLOAT          NULL DEFAULT(0.0)
      )
   
   CREATE INDEX IDX_LLI1 ON #TMP_LLI ( Lot, Loc, ID ) 

   CREATE TABLE #TMP_RESULT
      (  RowRef               INT      IDENTITY(1,1)
      ,  Facility             NVARCHAR(5)    NULL DEFAULT('')
      ,  LoadKeyStart         NVARCHAR(10)   NULL DEFAULT('')
      ,  LoadKeyEnd           NVARCHAR(10)   NULL DEFAULT('')
      ,  Storerkey            NVARCHAR(15)   NULL DEFAULT('')
      ,  Sku                  NVARCHAR(20)   NULL DEFAULT('')
      ,  Lot                  NVARCHAR(10)   NULL DEFAULT('')
      ,  Loc                  NVARCHAR(10)   NULL DEFAULT('')
      ,  ID                   NVARCHAR(18)   NULL DEFAULT('')
      ,  LogicalLoc           NVARCHAR(10)   NULL DEFAULT('')
      ,  ToLoc                NVARCHAR(10)   NULL DEFAULT('')
      ,  Descr                NVARCHAR(60)   NULL DEFAULT('')
      ,  Size                 NVARCHAR(10)   NULL DEFAULT('')
      ,  Packkey              NVARCHAR(10)   NULL DEFAULT('')
      ,  CaseCnt              FLOAT          NULL DEFAULT(0.0)
      ,  Qty                  INT            NULL DEFAULT(0)
      ,  QtyInCS              INT            NULL DEFAULT(0)
      ,  QtyInEA              INT            NULL DEFAULT(0)
      ,  QtyPicked            INT            NULL DEFAULT(0)
      ,  QtyPickedInCS        INT            NULL DEFAULT(0)
      ,  QtyPickedInEA        INT            NULL DEFAULT(0)
      ,  QtyReplenToLoc       INT            NULL DEFAULT(0)
      ,  QtyReplenToLocInCS   INT            NULL DEFAULT(0)
      ,  QtyReplenToLocInEA   INT            NULL DEFAULT(0)
      ,  QtyBal               INT            NULL DEFAULT(0)
      ,  QtyBalInCS           INT            NULL DEFAULT(0)
      ,  QtyBalInEA           INT            NULL DEFAULT(0)
      ,  LocQtyAvail          INT            NULL DEFAULT(0)
      ,  LocQtyAvailInCS      INT            NULL DEFAULT(0)
      ,  LocQtyAvailInEA      INT            NULL DEFAULT(0)
      ,  LocQtyReplen         INT            NULL DEFAULT(0)
      ,  LocQtyReplenInCS     INT            NULL DEFAULT(0)
      ,  LocQtyReplenInEA     INT            NULL DEFAULT(0)
      ,  LocQtyBal            INT            NULL DEFAULT(0)
      ,  LocQtyBalInCS        INT            NULL DEFAULT(0)
      ,  LocQtyBalInEA        INT            NULL DEFAULT(0)
      ,  TotalLoc             INT            NULL DEFAULT(0)
      )

   CREATE INDEX IDX_RESULT1 ON #TMP_RESULT( Loc, Storerkey, Sku ) 

   INSERT INTO #TMP_PICK (Storerkey, Sku, Lot, Loc, ID, QtyPicked)
   SELECT PD.Storerkey
         ,PD.Sku
         ,PD.Lot
         ,PD.Loc
         ,PD.ID
         ,QtyPicked= SUM(PD.Qty)
   FROM ORDERS     OH  WITH (NOLOCK)
   JOIN PICKDETAIL PD  WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)
   WHERE OH.Storerkey = @c_Storerkey    
   AND   OH.Facility  = @c_Facility
   AND   OH.Loadkey BETWEEN @c_LoadKeyStart AND @c_LoadKeyEnd
   AND   EXISTS ( SELECT 1 FROM  SKUxLOC SxL WITH (NOLOCK) 
                  WHERE PD.Storerkey = SxL.Storerkey
                  AND PD.Sku = SxL.Sku
                  AND PD.Loc = SxL.Loc
                  AND SxL.LocationType <> 'PICK'
                  AND SxL.Qty > 0 )
   AND   PD.Status = '0'
   AND   PD.Qty > 0
   GROUP BY PD.Storerkey
         ,  PD.Sku
         ,  PD.Lot
         ,  PD.Loc
         ,  PD.ID

   INSERT INTO #TMP_REPL (Storerkey, Sku, Lot, Loc, ID, ToLoc, QtyReplen)
   SELECT RPL.Storerkey
         ,RPL.Sku
         ,RPL.Lot
         ,RPL.FromLoc
         ,RPL.ID
         ,RPL.Toloc
         ,QtyReplen = SUM(RPL.Qty)
   FROM REPLENISHMENT RPL WITH (NOLOCK)
   JOIN SKUxLOC       SxL WITH (NOLOCK) ON (RPL.Storerkey = SxL.Storerkey)
                                        AND(RPL.Sku = SxL.Sku)
                                        AND(RPL.FromLoc = SxL.Loc)
   JOIN LOC           LOC WITH (NOLOCK) ON (RPL.FromLoc = LOC.Loc)
   WHERE RPL.Storerkey = @c_Storerkey    
   AND   LOC.Facility  = @c_Facility
   AND   SxL.LocationType <> 'PICK' 
   AND   RPL.Confirmed = 'N'
   AND   RPL.ReplenNo <> 'Y'
   GROUP BY RPL.Storerkey
         ,  RPL.Sku
         ,  RPL.Lot
         ,  RPL.FromLoc
         ,  RPL.ID
         ,  RPL.Toloc

   INSERT INTO #TMP_PICK (Storerkey, Sku, Lot, Loc, ID, QtyPicked)
   SELECT DISTINCT 
          RPL.Storerkey
         ,RPL.Sku
         ,RPL.Lot
         ,RPL.Loc
         ,RPL.ID
         ,QtyPicked= 0
   FROM #TMP_REPL RPL  WITH (NOLOCK)
   WHERE (  SELECT COUNT(1) FROM #TMP_PICK PCK 
            WHERE PCK.Storerkey = RPL.Storerkey
            AND   PCK.Sku = RPL.Sku
            AND   PCK.Loc = RPL.Loc ) = 0

   INSERT INTO #TMP_LLI (Storerkey, Sku, Lot, Loc, ID, QtyAvail, Packkey, CaseCnt)
   SELECT DISTINCT 
          LLI.Storerkey
         ,LLI.Sku
         ,LLI.Lot
         ,LLI.Loc
         ,LLI.ID
         ,QtyAvail = LLI.Qty  - LLI.QtyAllocated - LLI.QtyPicked
         ,PCK.Packkey
         ,PCK.CaseCnt
   FROM #TMP_PICK PK
   JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (PK.Loc = LLI.Loc)
   JOIN SKU        SKU WITH (NOLOCK) ON (LLI.Storerkey = SKU.Storerkey)
                                     AND(LLI.Sku = SKU.Sku)
   JOIN PACK       PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey) 

   -- Insert Replenishment Result 
   INSERT INTO #TMP_RESULT
         (
            Facility     
         ,  LoadKeyStart  
         ,  LoadKeyEnd    
         ,  Storerkey
         ,  Sku
         ,  Lot
         ,  Loc
         ,  ID
         ,  LogicalLoc
         ,  ToLoc
         ,  Descr
         ,  Size
         ,  Packkey
         ,  CaseCnt
         ,  QtyReplenToLoc
         )
   SELECT @c_Facility
         ,@c_LoadKeyStart
         ,@c_LoadKeyEnd
         ,SKU.Storerkey
         ,SKU.Sku
         ,''
         ,TMP.Loc
         ,''
         ,LogicalLoc = ISNULL(LOC.LogicalLocation,'')
         ,ToLoc = ISNULL(RTRIM(RPL.ToLoc),'')
         ,SKU.Descr
         ,Size = ISNULL(RTRIM(SKU.Size),'')
         ,PCK.Packkey
         ,PCK.CaseCnt
         ,QtyReplenToLoc = ISNULL(SUM(RPL.QtyReplen),0)
   FROM #TMP_PICK TMP
   JOIN LOC       LOC WITH (NOLOCK) ON (TMP.Loc = LOC.loc)
   JOIN SKU       SKU WITH (NOLOCK) ON (TMP.Storerkey = SKU.Storerkey)
                                    AND(TMP.Sku = SKU.Sku)
   JOIN PACK      PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.PackKey)
   LEFT JOIN #TMP_REPL RPL WITH (NOLOCK) ON (TMP.Lot = RPL.Lot)
                                    AND(TMP.Loc = RPL.Loc)
                                    AND(TMP.Id  = RPL.Id)
   GROUP BY SKU.Storerkey
         ,  SKU.Sku
         ,  TMP.Loc
         ,  ISNULL(LOC.LogicalLocation,'')
         ,  ISNULL(RTRIM(RPL.ToLoc),'')
         ,  SKU.Descr
         ,  ISNULL(RTRIM(SKU.Size),'')
         ,  PCK.Packkey
         ,  PCK.CaseCnt
   ORDER BY ISNULL(LOC.LogicalLocation,'')
         ,  TMP.Loc
         ,  SKU.Storerkey
         ,  SKU.Sku

   -- Get Total QtyAvail & QtyPicked for Replenish Sku & From LOC
   UPDATE TMP
      SET Qty       = LLI.QtyAvail + LLI.QtyPicked
         ,QtyInCS   = CASE WHEN TMP.CaseCnt > 0 THEN (LLI.QtyAvail + LLI.QtyPicked)/ TMP.CaseCnt ELSE 0 END
         ,QtyInEA   = CASE WHEN TMP.CaseCnt > 0 THEN LLI.QtyAvail + LLI.QtyPicked % CONVERT(INT,TMP.CaseCnt) ELSE 0 END
         ,QtyPicked = LLI.QtyPicked 
         ,QtyPickedInCS = CASE WHEN TMP.CaseCnt > 0 THEN LLI.QtyPicked / TMP.CaseCnt ELSE 0 END
         ,QtyPickedInEA = CASE WHEN TMP.CaseCnt > 0 THEN LLI.QtyPicked % CONVERT(INT,TMP.CaseCnt)  ELSE 0 END
         ,QtyReplenToLocInCS = CASE WHEN TMP.CaseCnt > 0 THEN TMP.QtyReplenToLoc / TMP.CaseCnt ELSE 0 END
         ,QtyReplenToLocInEA = CASE WHEN TMP.CaseCnt > 0 THEN TMP.QtyReplenToLoc % CONVERT(INT,TMP.CaseCnt)  ELSE 0 END
         ,QtyBal        = LLI.QtyAvail - TMP.QtyReplenToLoc
         ,QtyBalInCS    = CASE WHEN TMP.CaseCnt > 0 THEN (LLI.QtyAvail - TMP.QtyReplenToLoc) / TMP.CaseCnt ELSE 0 END
         ,QtyBalInEA    = CASE WHEN TMP.CaseCnt > 0 THEN (LLI.QtyAvail - TMP.QtyReplenToLoc) % CONVERT(INT,TMP.CaseCnt) ELSE 0 END
   FROM #TMP_RESULT   TMP
   JOIN (SELECT PK.Storerkey  
               ,PK.Sku
               ,PK.Loc 
               ,QtyAvail  = ISNULL(SUM(LLI.QtyAvail),0)
               ,QtyPicked = ISNULL(SUM(PK.QtyPicked),0)
         FROM  #TMP_PICK PK 
         JOIN  #TMP_LLI  LLI ON (PK.Lot = LLI.Lot)
                             AND(PK.Loc = LLI.Loc)
                             AND(PK.ID  = LLI.ID)
         GROUP BY PK.Storerkey
               ,  PK.Sku 
               ,  PK.Loc
         ) LLI ON (TMP.Storerkey = LLI.Storerkey)
               AND(TMP.Sku = LLI.Sku)
               AND(TMP.Loc = LLI.Loc) 

  UPDATE TMP
      SET LocQtyAvail     = LOCINV.LocQtyAvail
         ,LocQtyAvailInCS = LOCINV.LocQtyAvailInCS
         ,LocQtyAvailInEA = LOCINV.LocQtyAvailInEA
         ,LocQtyReplen    = LOCRPL.LocQtyReplen
         ,LocQtyReplenInCS= LOCRPL.LocQtyReplenInCS
         ,LocQtyReplenInEA= LOCRPL.LocQtyReplenInEA
         ,LocQtyBal       = LOCINV.LocQtyAvail - LOCRPL.LocQtyReplen
         ,LocQtyBalInCS   = LOCINV.LocQtyAvailInCS - LOCRPL.LocQtyReplenInCS
         ,LocQtyBalInEA   = LOCINV.LocQtyAvailInEA - LOCRPL.LocQtyReplenInEA
         ,TotalLoc        = ( SELECT COUNT(DISTINCT Loc) FROM #TMP_RESULT )
   FROM #TMP_RESULT   TMP
   JOIN (SELECT LLI.Loc 
               ,LocQtyAvail     = SUM(LLI.QtyAvail)
               ,LocQtyAvailInCS = SUM(CASE WHEN LLI.CaseCnt > 0 
                                           THEN (LLI.QtyAvail) / LLI.CaseCnt
                                           ELSE 0 
                                           END)
               ,LocQtyAvailInEA = SUM(CASE WHEN LLI.CaseCnt > 0 
                                           THEN (LLI.QtyAvail) % CONVERT(INT,LLI.CaseCnt) 
                                           ELSE 0 
                                           END)
         FROM #TMP_LLI LLI WITH (NOLOCK)
         GROUP BY LLI.Loc
         ) LOCINV ON (TMP.Loc = LOCINV.Loc) 
    JOIN (SELECT TRS.Loc 
               , LocQtyReplen     = SUM(TRS.QtyReplenToLoc)
               , LocQtyReplenInCS = SUM(TRS.QtyReplenToLocInCS)
               , LocQtyReplenInEA = SUM(TRS.QtyReplenToLocInEA)
         FROM  #TMP_RESULT TRS WITH (NOLOCK)
         GROUP BY TRS.Loc
         ) LOCRPL ON (TMP.Loc = LOCRPL.Loc) 

   SELECT RowRef
      ,  Facility    
      ,  LoadKeyStart 
      ,  LoadKeyEnd   
      ,  Storerkey
      ,  Sku
      ,  Lot
      ,  Loc
      ,  ID
      ,  ToLoc
      ,  Descr
      ,  Size
      ,  Packkey
      ,  CaseCnt
      ,  Qty            
      ,  QtyInCS        
      ,  QtyInEA       
      ,  QtyPicked      
      ,  QtyPickedInCS  
      ,  QtyPickedInEA  
      ,  QtyReplenToLoc      
      ,  QtyReplenToLocInCS 
      ,  QtyReplenToLocInEA  
      ,  QtyBal       
      ,  QtyBalInCS   
      ,  QtyBalInEA   
      ,  LocQtyBal      
      ,  LocQtyBalInCS   
      ,  LocQtyBalInEA  
      ,  TotalLoc
   FROM #TMP_RESULT
   ORDER BY RowRef

QUIT_SP:
   DROP TABLE #TMP_PICK
   DROP TABLE #TMP_REPL
   DROP TABLE #TMP_LLI
   DROP TABLE #TMP_RESULT
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO