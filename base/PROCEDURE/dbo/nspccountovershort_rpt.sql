SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCCountOverShort_rpt                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspCCountOverShort_rpt]

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   CREATE TABLE #TEMP_SKU
   (SKU   NVARCHAR(20) NULL,
   DESCR NVARCHAR(60) NULL,
   PACKKEY NVARCHAR(10) NULL,
   CCSHEETNO NVARCHAR(10) NULL,
   LOC NVARCHAR(10),
   SQTY INT,
   CQTY INT)

   SELECT S.SKU, SQTY=SUM(S.QTY)
   INTO  #SYSQTY
   FROM LOTxLOCxID S (nolock), SKU C (nolock)
   WHERE S.SKU = C.SKU
   AND   S.STORERKEY = C.STORERKEY
   AND   C.ITEMCLASS = "SPARES"
   GROUP BY S.SKU

   SELECT S.SKU, S.LOC, SQTY=SUM(S.QTY)
   INTO  #SYS_SKUxLOC
   FROM LOTxLOCxID S (nolock), SKU C (nolock)
   WHERE S.SKU = C.SKU
   AND   S.STORERKEY = C.STORERKEY
   AND   C.ITEMCLASS = "SPARES"
   GROUP BY S.SKU, S.LOC

   SELECT S.SKU, CQTY=SUM(S.QTY)
   INTO  #CYCQTY
   FROM CCDETAIL S (nolock), SKU C (nolock)
   WHERE S.SKU = C.SKU
   AND   S.STORERKEY = C.STORERKEY
   AND   C.ITEMCLASS = "SPARES"
   GROUP BY S.SKU

   SELECT S.SKU, S.LOC, CQTY=SUM(S.QTY)
   INTO  #CYC_SKUxLOC
   FROM CCDETAIL S (nolock), SKU C (nolock)
   WHERE S.SKU = C.SKU
   AND   S.STORERKEY = C.STORERKEY
   AND   C.ITEMCLASS = "SPARES"
   GROUP BY S.SKU, S.LOC

   DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT S.SKU
   FROM #SYSQTY S, #CYCQTY C
   WHERE S.SKU = C.SKU
   AND   SQTY <> CQTY
   UNION
   SELECT C.SKU
   FROM   #CYCQTY C
   WHERE  SKU NOT IN (SELECT SKU FROM #SYSQTY)

   DECLARE @c_sku NVARCHAR(20)

   OPEN CUR1

   FETCH NEXT FROM CUR1 INTO @C_SKU

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      INSERT INTO #TEMP_SKU
      SELECT C.SKU,        SKU.DESCR,
      PACK.PACKKEY, CCDETAIL.CCSHEETNO,
      C.LOC, S.SQTY, CCDETAIL.QTY
      FROM  #CYC_SKUxLOC C, #SYS_SKUxLOC S, SKU (nolock), PACK (nolock), CCDETAIL (nolock)
      WHERE C.SKU = S.SKU
      AND   C.LOC = S.LOC
      AND   SKU.SKU = C.SKU
      AND   SKU.PACKKEY = PACK.PACKKEY
      AND   CCDETAIL.SKU = C.SKU
      AND   CCDETAIL.LOC = C.LOC
      AND   C.SKU = @C_SKU
      ORDER BY C.SKU, C.LOC

      INSERT INTO #TEMP_SKU
      SELECT C.SKU,        SKU.DESCR,
      PACK.PACKKEY, CCDETAIL.CCSHEETNO,
      C.LOC, 0, CCDETAIL.QTY
      FROM  #CYC_SKUxLOC C, SKU (nolock), PACK (nolock), CCDETAIL (nolock)
      WHERE SKU.SKU = C.SKU
      AND   SKU.PACKKEY = PACK.PACKKEY
      AND   CCDETAIL.SKU = C.SKU
      AND   CCDETAIL.LOC = C.LOC
      AND   C.SKU = @C_SKU
      AND   C.SKU + C.LOC NOT IN ( SELECT C.SKU + C.LOC FROM #SYS_SKUxLOC C WHERE C.SKU = @c_SKU)
      ORDER BY C.SKU, C.LOC

      INSERT INTO #TEMP_SKU
      SELECT S.SKU,        SKU.DESCR,
      PACK.PACKKEY, '',
      S.LOC, S.SQTY, 0
      FROM  #SYS_SKUxLOC S, SKU (nolock), PACK (nolock)
      WHERE SKU.SKU = S.SKU
      AND   SKU.PACKKEY = PACK.PACKKEY
      AND   S.SKU = @C_SKU
      AND   S.SQTY > 0
      AND   S.SKU + S.LOC NOT IN ( SELECT C.SKU + C.LOC FROM #CYC_SKUxLOC C WHERE C.SKU = @c_SKU )
      ORDER BY S.SKU, S.LOC

      FETCH NEXT FROM CUR1 INTO @C_SKU
   END
   DEALLOCATE CUR1

   SELECT * FROM #TEMP_SKU

   --SELECT SUM(CQTY) - SUM(SQTY)
   --from #temp_sku
END


GO