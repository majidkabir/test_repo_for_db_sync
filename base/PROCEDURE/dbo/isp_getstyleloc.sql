SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_GetStyleLoc                                            */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 27-Feb-2017  TLTING   1.3  Variable Nvarchar                            */
/***************************************************************************/    
CREATE PROC [dbo].[isp_GetStyleLoc] (   
            @c_storerkey  NVARCHAR(15),
				@c_facility	  NVARCHAR(10))  
AS
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF 
	
	DECLARE @c_style        NVARCHAR(20)
	       ,@c_loc          NVARCHAR(10)
	       ,@c_company      NVARCHAR(60)
	       ,@c_bomsku       NVARCHAR(20)
	       ,@n_Bomqty       INT
	       ,@n_casecnt      INT
	       ,@n_qty          INT
	       ,@c_prevstyle    NVARCHAR(20)
	       ,@c_storerkey_1  NVARCHAR(15)
	       ,@c_sku          NVARCHAR(20)
	       ,@c_color        NVARCHAR(10)
	       ,@c_size         NVARCHAR(5)
	       ,@n_minwgt       FLOAT
	       ,@n_maxwgt       FLOAT
	       ,@n_mincube      FLOAT
	       ,@n_maxcube      FLOAT
	   
	CREATE TABLE #Tempstyleloc
	(
	   Storerkey  NVARCHAR(15)
	   ,Company   NVARCHAR(60)
	   ,Style     NVARCHAR(20)
	   ,loc       NVARCHAR(10)
	   ,BomSku    NVARCHAR(20)
	   ,BomQty    INT
	   ,Casecnt   INT
	   ,Mincube   FLOAT
	   ,Maxcube   FLOAT
	   ,Minwgt    FLOAT
	   ,Maxwgt    FLOAT
	) 

   DECLARE getstyleloc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
		select st.storerkey, St.company, lli.loc, ISNULL(BOM.Sku,'***N/A***'), S.Sku, S.Style, S.Color, S.size, ISNULL(BOM.Qty,0), ISNULL(P.Casecnt,0), 
				 SUM(lli.Qty), Min(stdgrosswgt), Max(stdgrosswgt), Min(stdcube), max(stdcube) 
		  from Storer St (nolock) JOIN lotxlocxid lli (nolock) ON st.storerkey = lli.storerkey 
				JOIN Loc l (nolock) ON (lli.loc = l.loc)
				JOIN Sku s (nolock) ON (lli.storerkey = s.storerkey and lli.sku = s.sku)
				JOIN Lotattribute LA (nolock) ON (lli.storerkey = la.storerkey and lli.sku = la.sku and lli.lot = la.lot)
				LEFT OUTER JOIN Billofmaterial BOM (nolock) ON (LA.Storerkey = BOM.Storerkey and LA.Lottable03 = BOM.Sku)
				LEFT OUTER JOIN UPC U (nolock) ON (BOM.Storerkey = U.Storerkey and BOM.SKU = U.Sku) and U.UOM = 'CS'
				LEFT OUTER JOIN PACK P (nolock) ON (U.packkey = P.Packkey)
		 where lli.storerkey = @c_storerkey and l.facility = @c_facility 
		   and lli.Qty > 0 
		group by st.storerkey, St.company, lli.loc, BOM.Sku, S.Sku, S.Style, S.Color, S.size, BOM.Qty, P.Casecnt
		order by st.storerkey, St.company, S.Style, lli.loc, BOM.Sku, S.Sku, S.Color, S.size 

	OPEN getstyleloc

	SET @c_prevstyle = ''
	SET @c_Style = ''

	FETCH NEXT FROM getstyleloc INTO @c_storerkey_1, @c_company, @c_loc, @c_bomsku, @c_sku, 
												@c_Style, @c_color, @c_size, @n_Bomqty, @n_casecnt, @n_qty,  
												@n_minwgt, @n_maxwgt, @n_mincube, @n_maxcube 


	WHILE (@@FETCH_STATUS <> -1)  
	BEGIN
		IF @c_prevstyle <> @c_Style
		BEGIN
			SET @c_prevstyle = @c_Style 

			Insert into #Tempstyleloc (Storerkey, Company, Style, loc, BomSku, BomQty, Casecnt,
												Mincube, Maxcube, Minwgt, Maxwgt)
									 VALUES (@c_storerkey, @c_company, @c_Style, @c_loc, @c_bomsku, @n_Bomqty, @n_casecnt,	
												@n_minwgt, @n_maxwgt, @n_mincube, @n_maxcube)
		END

		FETCH NEXT FROM getstyleloc INTO @c_storerkey_1, @c_company, @c_loc, @c_bomsku, @c_sku, 
													@c_Style, @c_color, @c_size, @n_Bomqty, @n_casecnt, @n_qty,  
												   @n_minwgt, @n_maxwgt, @n_mincube, @n_maxcube  

	END

	CLOSE getstyleloc
	DEALLOCATE getstyleloc 

	Select * from #Tempstyleloc order by loc, style

END

GO