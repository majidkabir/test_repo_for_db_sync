SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_DiageoSG_KittingPalletLabel					   	*/
/* Creation Date: 16-Aug-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#55167 - Diageo SG - RCM Kitting Pallet Label printing.	*/
/*          It generates x number of label according to total pallet 	*/
/*                                                                      */
/* Called By: 																				*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
 
CREATE PROC [dbo].[isp_DiageoSG_KittingPalletLabel]
   @c_Kitkey   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @c_kitlineno     NVARCHAR(5)	
		  , @n_qtyincase     INT
        , @n_prevqtyincase INT
		  , @n_casefrom      INT
        , @n_prevcasefrom  INT
        , @n_Rowid         INT
		  , @b_debug         INT

  SELECT @b_debug = 0
  SELECT @n_Rowid = 0
  SELECT @n_casefrom = 0
  SELECT @n_prevcasefrom = 0

  SELECT KITDETAIL.KitKey,
         KITDETAIL.Lottable03, 
			KIT.UsrDef3,
	   	KITDETAIL.SKU, 
			SKU.Descr, 
			SKU.AltSKU, 
  		   KITDETAIL.Lottable01, 
			PACK.Pallet, 
			PACK.CaseCnt, 
			QTY = KITDETAIL.QTY,
         KITDETAIL.UOM,
			QtyInCase = CASE WHEN PACK.Casecnt > 0 THEN Floor(KITDETAIL.Qty / PACK.Casecnt) 
                     ELSE KITDETAIL.Qty END,
			CaseFrom = 0,
         KITDETAIL.KITLineNumber,
         RowID = IDENTITY(int, 1,1)
	INTO  #RESULT1
	FROM  KITDETAIL (NOLOCK)
	JOIN 	KIT (NOLOCK) ON (KIT.KitKey = KITDETAIL.KitKey)
	JOIN	SKU (NOLOCK) ON (SKU.StorerKey = KITDETAIL.StorerKey AND SKU.Sku = KITDETAIL.Sku)
	JOIN 	PACK (NOLOCK) ON (PACK.PackKey = KITDETAIL.PackKey)
	WHERE KITDETAIL.KitKey = @c_Kitkey
   AND   KITDETAIL.Type = 'T'
   Order By KITDETAIL.KitKey,KITDETAIL.KITLineNumber

	-- Calculate Case From
	DECLARE case_cur CURSOR FAST_FORWARD READ_ONLY FOR
	SELECT R.RowID, R.QtyInCase, R.KitKey
	FROM   #RESULT1 R (NOLOCK)	
	WHERE  CaseFrom = 0
	ORDER BY R.RowID
	
	OPEN case_cur 	

	FETCH NEXT FROM case_cur INTO @n_Rowid, @n_qtyincase, @c_KitKey

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
      IF @n_Rowid = 1
      BEGIN
		  SELECT @n_casefrom = 1
      END
      ELSE
      BEGIN
        SELECT @n_casefrom = @n_prevcasefrom + @n_prevqtyincase
      END

      SELECT @n_prevcasefrom = @n_casefrom
      SELECT @n_prevqtyincase = @n_qtyincase

      IF @b_debug = 1
      BEGIN
	      SELECT '@n_casefrom', @n_casefrom
	      SELECT '@n_prevcasefrom', @n_prevcasefrom 
	      SELECT '@n_prevqtyincase', @n_prevqtyincase
      END

		UPDATE #RESULT1
		SET	 CaseFrom = @n_casefrom	
		WHERE  KitKey = @c_KitKey
		AND    RowID = @n_Rowid		

		FETCH NEXT FROM case_cur INTO @n_Rowid, @n_qtyincase, @c_KitKey
	END
	CLOSE case_cur
	DEALLOCATE case_cur
	-- End : Calculate Case From

   -- Write the label line 
   SELECT Lottable03,
			 UsrDef3,
	   	 SKU, 
			 Descr, 
			 AltSKU, 
  		    Lottable01, 
			 Pallet, 
          RIGHT(dbo.fnc_RTrim(REPLICATE(0, 4) + CONVERT(CHAR, QtyInCase)), 4) as QtyInCase,
          RIGHT(dbo.fnc_RTrim(REPLICATE(0, 4) + CONVERT(CHAR, CaseFrom)), 4) as CaseFrom
-- 			 QtyInCase, 
-- 			 CaseFrom
	INTO  #RESULT
	FROM  #RESULT1


   SELECT * FROM #RESULT
	ORDER BY CaseFrom

   DROP TABLE #RESULT
   DROP TABLE #RESULT1
END


SET QUOTED_IDENTIFIER OFF 

GO