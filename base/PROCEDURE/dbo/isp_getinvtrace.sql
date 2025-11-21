SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetInvTrace                                    */
/* Creation Date: 17-Mar-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Parameters: (Input)                                                  */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 2014-04-29   CSCHONG   Add Lottable06-15 (CS01)                      */
/* 2017-07-15   TLTING    review DynamicSQL, remove setrowcount         */
/* 2019-09-24   TLTING    Performance tune                              */
/* 2020-01-30   TLTING02  Performance tune                              */
/* 2020-02-28   TLTING02  TraceInfo                                     */
/* 2020-02-28   TLTING03  Performance tune                              */
/************************************************************************/

/*

   INSERT INTO CodeLKUP (LISTNAME,Code,Description,Short, Long)
   Select 'TraceInfo', 'GetInvTrace','isp_GetInvTrace log', 1 , ''

   */

CREATE PROCEDURE [dbo].[isp_GetInvTrace]
        @dt_date_start datetime,
        @dt_date_end datetime,
        @c_facility_start NVARCHAR(5),
        @c_facility_end NVARCHAR(5),        
        @c_storerkey_start NVARCHAR(15),
        @c_storerkey_end NVARCHAR(15),
        @c_sku_start NVARCHAR(20),
        @c_sku_end NVARCHAR(20),
        @c_style_start NVARCHAR(20),
        @c_style_end NVARCHAR(20),
        @c_color_start NVARCHAR(10),
        @c_color_end NVARCHAR(10),
        @c_size_start NVARCHAR(5),
        @c_size_end NVARCHAR(5),
        @c_measurement_start NVARCHAR(5),
        @c_measurement_end NVARCHAR(5),
        @c_lot_start NVARCHAR(10),
        @c_lot_end NVARCHAR(10),
        @c_loc_start NVARCHAR(10),
        @c_loc_end NVARCHAR(10),
        @c_id_start NVARCHAR(18),
        @c_id_end NVARCHAR(18),
        @c_lottable01_start NVARCHAR(18),
        @c_lottable01_end NVARCHAR(18),
        @c_lottable02_start NVARCHAR(18),
        @c_lottable02_end NVARCHAR(18),
        @c_lottable03_start NVARCHAR(18),
        @c_lottable03_end NVARCHAR(18),
        @c_lottable04_start NVARCHAR(30),
        @c_lottable04_end NVARCHAR(30),
        @c_lottable05_start NVARCHAR(30),
        @c_lottable05_end NVARCHAR(30),
		  /*CS01 Start*/
		  @c_lottable06_start NVARCHAR(30),
        @c_lottable06_end NVARCHAR(30),
        @c_lottable07_start NVARCHAR(30),
        @c_lottable07_end NVARCHAR(30),
        @c_lottable08_start NVARCHAR(30),
        @c_lottable08_end NVARCHAR(30),
        @c_lottable09_start NVARCHAR(30),
        @c_lottable09_end NVARCHAR(30),
        @c_lottable10_start NVARCHAR(30),
		  @c_lottable10_end NVARCHAR(30),
		  @c_lottable11_start NVARCHAR(30),
        @c_lottable11_end NVARCHAR(30),
        @c_lottable12_start NVARCHAR(30),
        @c_lottable12_end NVARCHAR(30),
        @c_lottable13_start NVARCHAR(30),
        @c_lottable13_end NVARCHAR(30),
        @c_lottable14_start NVARCHAR(30),
        @c_lottable14_end NVARCHAR(30),
        @c_lottable15_start NVARCHAR(30),
        @c_lottable15_end NVARCHAR(30),
		  /*CS01 end*/
        @c_trantype NVARCHAR(10),
        @n_CutOffMonth   int  = 12   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 	@n_continue int,
            @n_cnt int,
            @n_rowid int,
            @c_sourcetype NVARCHAR(30),
            @c_sourcekey NVARCHAR(20),
            @c_sourcetypedesc NVARCHAR(30),
            @c_referencekey NVARCHAR(30),
            @c_externreferencekey NVARCHAR(30),
            @c_externreferencetype NVARCHAR(30),
            @c_remarks NVARCHAR(215),
            @c_trantype2 NVARCHAR(10),
            @c_arcdbname NVARCHAR(30),    
            @sql nvarchar(4000),
            @c_SQLArgument NVARCHAR(4000)
  
   DECLARE @c_cnt1 INT = 0
   DECLARE @c_cnt2 INT = 0
   DECLARE @c_cnt3 INT = 0
   DECLARE @d_CutofDate datetime 

   IF @n_CutOffMonth < 1
      SET @n_CutOffMonth = 3
   
   SET @d_CutofDate = dateadd(month, 0 - @n_CutOffMonth, getdate())
    
  --  Select dateadd(month, 0 - @n_CutOffMonth, getdate())

  --  Select convert(datetime, left('0000'+ cast( year(@d_CutofDate ) as varchar), 4) + left('00' +  cast( MONTH(@d_CutofDate ) as varchar) , 2)  + '01' )

  -- SET @d_CutofDate = DATEADD(month, DATEDIFF(month, 0, @d_CutofDate), 0)   -- 1st day of month
   
   SET @d_CutofDate = DATEADD(DAY,1,EOMONTH(@d_CutofDate,-1))
 

  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,  
           @d_Trace_Step2      DATETIME, 
           @d_Trace_Step3      DATETIME, 
           @d_Trace_Step4      DATETIME, 
           @d_Trace_Step5      DATETIME, 
           @c_Trace_Step1      NVARCHAR(20),    
           @c_Trace_Step2      NVARCHAR(20), 
           @c_Trace_Step3      NVARCHAR(20), 
           @c_Trace_Step4      NVARCHAR(20),
           @c_Trace_Step5      NVARCHAR(20),   
           @c_Trace_Col1      NVARCHAR(20),    
           @c_Trace_Col2      NVARCHAR(20), 
           @c_Trace_Col3      NVARCHAR(20), 
           @c_Trace_Col4      NVARCHAR(20),
           @c_Trace_Col5      NVARCHAR(20),           
           @c_UserName         NVARCHAR(20),  
           @c_ExecArguments    NVARCHAR(4000)       
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
   SET @c_Trace_Col1= ''
   SET @c_Trace_Col2= ''
   SET @c_Trace_Col3= ''
   SET @c_Trace_Col4= ''
   SET @c_Trace_Col5= ''

   SELECT @c_arcdbname = ISNULL(NSQLValue,'') 
   FROM NSQLCONFIG (NOLOCK)    
   WHERE ConfigKey='ArchiveDBName' 
   
   CREATE TABLE #TMP_REF
      (ROWRef  INT NOT NULL Identity(1,1) Primary key,
       Referencekey NVARCHAR(30) NULL,
       ExternReferencekey NVARCHAR(30) NULL,
       ExternReferenceType NVARCHAR(30) NULL,
       Remarks NVARCHAR(215) NULL)
       
   CREATE TABLE #COMBINE_ITRN
      (storerkey NVARCHAR(15) NULL,
       effectivedate datetime NULL,
       sourcetype NVARCHAR(30) NULL,
       trantype NVARCHAR(10) NULL,
       sku NVARCHAR(20) NULL,
       fromloc NVARCHAR(10) NULL,
       toloc NVARCHAR(10) NULL,
       fromid NVARCHAR(18) NULL,
       toid NVARCHAR(18) NULL,
       lot NVARCHAR(10) NULL,
       qty int NULL,
       uom NVARCHAR(10) NULL,
       addwho NVARCHAR(18) NULL,
       adddate datetime NULL,
       editwho NVARCHAR(18) NULL,
       editdate datetime NULL,
       sourcekey NVARCHAR(20) NULL,
       itrnkey NVARCHAR(10) NULL)
       
 
   CREATE TABLE #TMP_ITRN
      (rowid INT NOT NULL identity(1,1) primary key ,
       storerkey NVARCHAR(15) NULL,
       Facility NVARCHAR(5) NULL,
       effectivedate datetime NULL,
       sourcetype NVARCHAR(30) NULL,
       trantype NVARCHAR(10) NULL,
       sku NVARCHAR(20) NULL,
       fromloc NVARCHAR(10) NULL,
       toloc NVARCHAR(10) NULL,
       fromid NVARCHAR(18) NULL,
       toid NVARCHAR(18) NULL,
       lot NVARCHAR(10) NULL,
       qty int NULL,
       caseqty int NULL,
       ipqty  int NULL,
       uom NVARCHAR(10) NULL,
       Lottable01	nvarchar(18) NULL,
       Lottable02	nvarchar	(18) NULL,
       Lottable03	nvarchar	(18) NULL,
       Lottable04	datetime	NULL,
       Lottable05	datetime	NULL,
       Lottable06	nvarchar	(30) NULL,
       Lottable07	nvarchar	(30) NULL,
       Lottable08	nvarchar	(30) NULL,
       Lottable09	nvarchar	(30) NULL,
       Lottable10	nvarchar	(30) NULL,
       Lottable11	nvarchar	(30) NULL,
       Lottable12	nvarchar	(30) NULL,
       Lottable13	datetime	NULL,
       Lottable14	datetime	NULL,
       Lottable15	datetime	NULL, 
       addwho NVARCHAR(18) NULL,
       adddate datetime NULL,
       editwho NVARCHAR(18) NULL,
       editdate datetime NULL,
       sourcekey NVARCHAR(20) NULL,
       SourceTypeDesc   NVARCHAR(30) NULL,
       ReferenceKey NVARCHAR(30) NULL,
       ExternReferenceKey NVARCHAR(30) NULL,
       ExternReferenceType NVARCHAR(30) NULL,
       Remarks NVARCHAR(215) NULL,
       itrnkey NVARCHAR(10) NULL  )
  
   SELECT @n_continue = 1 
	
	 IF @n_continue = 1 OR @n_continue = 2
	 BEGIN
	 	 INSERT INTO #COMBINE_ITRN	 	 
	   SELECT ITRN.Storerkey, ITRN.adddate, ITRN.SourceType, ITRN.Trantype, ITRN.Sku,
            ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, ITRN.UOM, 
            ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey, ITRN.Itrnkey
     FROM ITRN (NOLOCK)
     WHERE (ITRN.Storerkey BETWEEN @c_storerkey_start AND @c_storerkey_end)
     AND (ITRN.Sku BETWEEN @c_sku_start AND @c_sku_end)
     AND (ITRN.Lot BETWEEN @c_lot_start AND @c_lot_end)
     AND ((ITRN.FromLoc BETWEEN @c_loc_start AND @c_loc_end) 
         OR (ITRN.ToLoc BETWEEN @c_loc_start AND @c_loc_end))
     AND ((ITRN.FromID BETWEEN @c_id_start AND @c_id_end)
         OR (ITRN.ToID BETWEEN @c_id_start AND @c_id_end))
		 AND (ITRN.Adddate BETWEEN @dt_date_start AND @dt_date_end)
     AND (ITRN.Trantype = @c_trantype OR @c_trantype='ALL')
     OPTION(RECOMPILE)   --tlting02
     SET @c_cnt2 = @@ROWCOUNT

     IF ISNULL(RTRIM(@c_arcdbname),'') <> ''
     BEGIN
        SELECT @sql = 'INSERT INTO #COMBINE_ITRN ' +     
        + ' SELECT TOP 1000000 ITRN.Storerkey, ITRN.adddate, ITRN.SourceType, ITRN.Trantype, ITRN.Sku, '     
        + '        ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, ITRN.UOM, '     
        + '        ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey, ITRN.Itrnkey '     
        + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.ITRN ITRN (NOLOCK) '     
        + ' WHERE ( ITRN.adddate >=  @d_CutofDate )  ' --tlting03 
        + ' AND (ITRN.Storerkey BETWEEN RTRIM(@c_storerkey_start) AND RTRIM(@c_storerkey_end) ) '
        + ' AND (ITRN.Sku BETWEEN RTRIM(@c_sku_start)  AND RTRIM(@c_sku_end) ) '
        + ' AND (ITRN.Lot BETWEEN RTRIM(@c_lot_start)  AND  RTRIM(@c_lot_end) )'
        + ' AND ((ITRN.FromLoc BETWEEN RTRIM(@c_loc_start)  AND  RTRIM(@c_loc_end) ) '
        + ' OR (ITRN.ToLoc BETWEEN RTRIM(@c_loc_start) AND RTRIM(@c_loc_end) )) '
        + ' AND ((ITRN.FromID BETWEEN RTRIM(@c_id_start)  AND RTRIM(@c_id_end) ) '
        + ' OR (ITRN.ToID BETWEEN RTRIM(@c_id_start)  AND RTRIM(@c_id_end) )) '
		  + ' AND (ITRN.Adddate BETWEEN @dt_date_start AND @dt_date_end ) '
        + ' AND (ITRN.Trantype = RTRIM(@c_trantype) OR RTRIM(@c_trantype)=N''ALL'') '
        + ' ORDER BY ITRN.adddate DESC '
        + ' OPTION(RECOMPILE) '  --tlting02
  
  
         SET @c_SQLArgument = ''
         SET @c_SQLArgument = N'@c_storerkey_start nvarchar(15) ' +
                                 ', @c_storerkey_end nvarchar(15) ' +
                                 ', @c_sku_start nvarchar(20) ' +
                                 ', @c_sku_end nvarchar(20) ' +
                                 ', @c_lot_start nvarchar(10) ' +
                                 ', @c_lot_end nvarchar(10) ' +
                                 ', @c_loc_start nvarchar(10) ' +
                                 ', @c_loc_end nvarchar(10) ' +
                                 ', @c_id_start nvarchar(18) ' +
                                 ', @c_id_end nvarchar(18) ' +
                                 ', @dt_date_start datetime ' +
                                 ', @dt_date_end datetime ' +
                                 ', @c_trantype nvarchar(18) '  +
                                 ', @d_CutofDate datetime ' 

         EXEC sp_executesql @sql, @c_SQLArgument, @c_storerkey_start, @c_storerkey_end
               , @c_sku_start, @c_sku_end, @c_lot_start, @c_lot_end
               , @c_loc_start, @c_loc_end, @c_id_start, @c_id_end
               , @dt_date_start, @dt_date_end, @c_trantype, @d_CutofDate  
         SET @c_cnt2 = @@ROWCOUNT
        --EXEC(@sql)         	  
     END


   SET @d_Trace_Step2 = GETDATE()    
  
   SET @c_Trace_Col1 = cast(@c_cnt1 as varchar)
   SET @c_Trace_Col2 = cast(@c_cnt2 as varchar)
 
       INSERT INTO  #TMP_ITRN   (    storerkey, Facility, effectivedate, sourcetype
            , trantype, sku, fromloc, toloc, fromid
            , toid, lot, qty, caseqty, ipqty
            , uom, Lottable01, Lottable02, Lottable03, Lottable04
            , Lottable05, Lottable06, Lottable07, Lottable08, Lottable09
            , Lottable10, Lottable11, Lottable12, Lottable13, Lottable14
            , Lottable15, addwho, adddate, editwho, editdate
            , sourcekey, SourceTypeDesc, ReferenceKey, ExternReferenceKey, ExternReferenceType
            , Remarks, itrnkey )

	   SELECT TOP 1000000 ITRN.Storerkey, LOC.Facility, ITRN.adddate AS Effectivedate, ITRN.SourceType, ITRN.Trantype,
            ITRN.Sku, ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, 
            CASE WHEN PACK.Casecnt > 0  THEN FLOOR(ITRN.Qty / PACK.Casecnt)
            ELSE 0 END AS caseqty,
            CASE WHEN PACK.InnerPack > 0 THEN FLOOR(ITRN.Qty / PACK.InnerPack)
            ELSE 0 END AS ipqty,
            ITRN.UOM, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05,
				LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10,              --(CS01)
				LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15,              --(CS01)
            ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey,
            CONVERT(NVARCHAR(30),'') AS SourceTypeDesc, CONVERT(NVARCHAR(30),'') AS ReferenceKey, 
            CONVERT(NVARCHAR(30),'') AS ExternReferenceKey, CONVERT(NVARCHAR(30),'') AS ExternReferenceType, 
            CONVERT(NVARCHAR(215),'') AS Remarks, ITRN.Itrnkey
     FROM #COMBINE_ITRN ITRN 
     JOIN LOC (NOLOCK) ON (ITRN.Toloc = LOC.Loc)
     JOIN LOTATTRIBUTE LA (NOLOCK) ON (ITRN.Lot = LA.Lot)
     JOIN SKU (NOLOCK) ON (ITRN.Storerkey = SKU.Storerkey AND ITRN.Sku = SKU.Sku)
     JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
     WHERE ITRN.adddate >=  @d_CutofDate   --tlting03
     AND (LOC.Facility BETWEEN @c_facility_start AND @c_facility_end)
     AND (ISNULL(SKU.Style,'') BETWEEN @c_style_start AND @c_style_end)
     AND (ISNULL(SKU.Color,'') BETWEEN @c_color_start AND @c_color_end)
     AND (ISNULL(SKU.Size,'') BETWEEN @c_size_start AND @c_size_end)
     AND (ISNULL(SKU.Measurement,'') BETWEEN @c_measurement_start AND @c_measurement_end)
     AND (ISNULL(LA.Lottable01,'') BETWEEN @c_lottable01_start AND @c_lottable01_end)
     AND (ISNULL(LA.Lottable02,'') BETWEEN @c_lottable02_start AND @c_lottable02_end)
     AND (ISNULL(LA.Lottable03,'') BETWEEN @c_lottable03_start AND @c_lottable03_end)
	  AND (CONVERT(NVARCHAR(20),ISNULL(LA.Lottable04,' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable04_start),120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable04_end), 120)) 
	  AND (CONVERT(NVARCHAR(20),ISNULL(LA.Lottable05,' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable05_start),120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable05_end), 120)) 
     /*CS01 start*/
	  AND (ISNULL(LA.Lottable06,'') BETWEEN @c_lottable06_start AND @c_lottable06_end)
     AND (ISNULL(LA.Lottable07,'') BETWEEN @c_lottable07_start AND @c_lottable07_end)
     AND (ISNULL(LA.Lottable08,'') BETWEEN @c_lottable08_start AND @c_lottable08_end)
	  AND (ISNULL(LA.Lottable09,'') BETWEEN @c_lottable09_start AND @c_lottable09_end)
     AND (ISNULL(LA.Lottable10,'') BETWEEN @c_lottable10_start AND @c_lottable10_end)
     AND (ISNULL(LA.Lottable11,'') BETWEEN @c_lottable11_start AND @c_lottable11_end)
	  AND (ISNULL(LA.Lottable12,'') BETWEEN @c_lottable12_start AND @c_lottable12_end)
	  AND (CONVERT(NVARCHAR(20),ISNULL(LA.Lottable13,' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable13_start),120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable13_end), 120)) 
	  AND (CONVERT(NVARCHAR(20),ISNULL(LA.Lottable14,' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable14_start),120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable14_end), 120)) 
	  AND (CONVERT(NVARCHAR(20),ISNULL(LA.Lottable15,' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable15_start),120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_lottable15_end), 120)) 
     /*CS01 END*/
--		 AND (ITRN.Adddate BETWEEN @dt_date_start AND @dt_date_end)
--     AND (ITRN.Trantype = @c_trantype OR @c_trantype='ALL')
     ORDER BY ITRN.Adddate desc, ITRN.Itrnkey desc    -- tlting03
     SET @c_cnt3 = @@ROWCOUNT
     
     -- CREATE UNIQUE INDEX PKTMP_ITRN ON #TMP_ITRN (rowid)

	 	SELECT @n_rowid = 0
      -- tlting03
      Truncate Table #COMBINE_ITRN
      DROP TABLE #COMBINE_ITRN

 
      SET @d_Trace_Step3 = GETDATE()         
      SET @c_Trace_Col3 = cast(@c_cnt3 as varchar)
      SET @c_Trace_Col4 = SUSER_SNAME()

      DECLARE C_ItemLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT rowid, sourcekey, ISNULL(sourcetype,''), trantype  
      FROM  #TMP_ITRN 
      Order by rowid desc

      OPEN C_ItemLoop  
      FETCH NEXT FROM C_ItemLoop INTO @n_rowid, @c_sourcekey, @c_sourcetype, @c_trantype2
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
 
 
	 	 	  --SELECT TOP 1 @n_rowid = rowid, @c_sourcekey = sourcekey, @c_sourcetype = ISNULL(sourcetype,''), @c_trantype2 = trantype
	 	 	  --FROM #TMP_ITRN
	 	 	  --WHERE rowid > @n_rowid
	 	 	  --ORDER BY rowid
	 	 	  
	 	 	  --SELECT @n_cnt = @@ROWCOUNT		 	  
       --    IF @n_cnt = 0
	 	    --   BREAK	 	    

           SELECT @c_sourcetypedesc = @c_sourcetype, @c_referencekey = @c_sourcekey, 
                @c_externreferencekey ='', @c_externreferencetype = '',
                @c_remarks = ''
	 	    
	 	     IF @c_trantype2 = 'MV'
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Inventory Move'	 	         
	 	     END

	 	     IF @c_sourcetype = 'ntrPickDetailUpdate'
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Orders'
	 	     
	 	         Truncate table #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks)
	 	         SELECT ORDERS.Orderkey, ORDERS.ExternOrderkey, 
	 	                ORDERS.Type, ORDERS.c_company
	 	         FROM PICKDETAIL (NOLOCK)
	 	         JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
	 	         WHERE PICKDETAIL.Pickdetailkey = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT ORDERS.Orderkey, ORDERS.ExternOrderkey, '     
                + '        ORDERS.Type, ORDERS.c_company '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.PICKDETAIL PICKDETAIL (NOLOCK) '     
                + ' JOIN '+RTRIM(@c_arcdbname)+'.dbo.ORDERS ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey) '
                + ' WHERE PICKDETAIL.Pickdetailkey = LEFT(@c_sourcekey,10) '
                
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey    
                -- EXEC(@sql)    
             END
                          
	 	         --IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF) 
               --TLTING01
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	         
	 	         /*SELECT @c_referencekey = ORDERS.Orderkey, @c_externreferencekey = ORDERS.ExternOrderkey, 
	 	                @c_externreferencetype = ORDERS.Type, @c_remarks = ORDERS.c_company
	 	         FROM PICKDETAIL (NOLOCK)
	 	         JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
	 	         WHERE PICKDETAIL.Pickdetailkey = LEFT(@c_sourcekey,10)*/
	 	     END
	 	     
	 	     IF @c_sourcetype = 'ntrReceiptDetailUpdate' OR @c_sourcetype = 'ntrReceiptDetailAdd'  
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Receipt'
	 	         
	 	         Truncate table #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks)
	 	         SELECT RECEIPT.Receiptkey, RECEIPT.ExternReceiptkey, 
	 	                RECEIPT.RecType, CONVERT(NVARCHAR(215),RECEIPT.Notes)
	 	         FROM RECEIPT (NOLOCK)
	 	         WHERE RECEIPT.Receiptkey = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT RECEIPT.Receiptkey, RECEIPT.ExternReceiptkey, '     
                + '        RECEIPT.RecType, CONVERT(NVARCHAR(215),RECEIPT.Notes) '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.RECEIPT RECEIPT (NOLOCK) '     
                + ' WHERE RECEIPT.Receiptkey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey   
             END
                          
	 	         --IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF) 
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	     END
	 	     
	 	     IF @c_sourcetype = 'ntrAdjustmentDetailUpdate' OR @c_sourcetype = 'ntrAdjustmentDetailAdd' 
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Adjustment'

	 	         Truncate table #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks)
	 	         SELECT ADJUSTMENT.Adjustmentkey, ADJUSTMENT.CustomerRefNo, 
	 	                ADJUSTMENT.AdjustmentType, CONVERT(NVARCHAR(215),ADJUSTMENT.Remarks)
	 	         FROM ADJUSTMENT (NOLOCK)
	 	         WHERE ADJUSTMENT.Adjustmentkey = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT ADJUSTMENT.Adjustmentkey, ADJUSTMENT.CustomerRefNo, '     
                + '        ADJUSTMENT.AdjustmentType, CONVERT(NVARCHAR(215),ADJUSTMENT.Remarks) '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.ADJUSTMENT ADJUSTMENT (NOLOCK) '     
                + ' WHERE ADJUSTMENT.Adjustmentkey = LEFT(@c_sourcekey,10) '
   
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey     
             END
                          
	 	         --IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF)
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	     END
	 	     
	 	     IF @c_sourcetype = 'ntrReplenishmentUpdate' 
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Replenishment'
	 	     END
	 	     
	 	     IF @c_sourcetype = 'WSPUTAWAY' 
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Put-Away'
	 	     END
	 	     	 	     	 	     
	 	     IF @c_sourcetype = 'ntrTransferDetailUpdate' 	 	      	 	     
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Transfer'

	 	         Truncate table  #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks)
	 	         SELECT TRANSFER.Transferkey, TRANSFER.CustomerRefNo, 
	 	                TRANSFER.Type, CONVERT(NVARCHAR(215),TRANSFER.Remarks)
	 	         FROM dbo.TRANSFER (NOLOCK)
	 	         WHERE TRANSFER.Transferkey = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT TRANSFER.Transferkey, TRANSFER.CustomerRefNo, '     
                + '        TRANSFER.Type, CONVERT(NVARCHAR(215),TRANSFER.Remarks) '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.TRANSFER TRANSFER (NOLOCK) '     
                + ' WHERE TRANSFER.Transferkey = LEFT(@c_sourcekey,10) '
   
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey      
             END
                          
	 	        -- IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF)
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	     END
	 	     
	 	     IF @c_sourcetype = 'ntrInventoryQCDetailUpdate' 
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'IQC'

	 	         Truncate table #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks)
	 	         SELECT INVENTORYQC.QC_Key, INVENTORYQC.RefNo, 
	 	                INVENTORYQC.Reason, CONVERT(NVARCHAR(215),INVENTORYQC.Notes)
	 	         FROM INVENTORYQC (NOLOCK)
	 	         WHERE INVENTORYQC.QC_Key = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT INVENTORYQC.QC_Key, INVENTORYQC.RefNo, '     
                + '        INVENTORYQC.Reason, CONVERT(NVARCHAR(215),INVENTORYQC.Notes) '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.INVENTORYQC INVENTORYQC (NOLOCK) '     
                + ' WHERE INVENTORYQC.QC_Key = LEFT(@c_sourcekey,10) '
   
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey      
             END
                          
	 	         --IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF)
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	     END
	 	     
	 	     IF (@c_sourcetype = 'ntrKitDetailAdd' OR @c_sourcetype = 'ntrKitDetailUpdate') 
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Kitting'

	 	         Truncate table #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks)
	 	         SELECT KIT.Kitkey, KIT.ExternKitKey, 
	 	                KIT.Type, CONVERT(NVARCHAR(215),KIT.Remarks)
	 	         FROM KIT (NOLOCK)
	 	         WHERE KIT.Kitkey = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT KIT.Kitkey, KIT.ExternKitKey, '     
                + '        KIT.Type, CONVERT(NVARCHAR(215),KIT.Remarks) '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.KIT KIT (NOLOCK) '     
                + ' WHERE KIT.KitKey = LEFT(@c_sourcekey,10) '
   
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey     
             END
                          
	 	         --IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF)  
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	     END
	 	      
	 	     IF (LEFT(@c_sourcetype,10) = 'CC Deposit' OR LEFT(@c_sourcetype,13) = 'CC Withdrawal') 
	 	     BEGIN
	 	         SET @c_sourcetypedesc = 'Count'
	 	         
	 	         Truncate table #TMP_REF
	 	         
	 	         INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) 
	 	         SELECT STOCKTAKESHEETPARAMETERS.StockTakeKey, STOCKTAKESHEETPARAMETERS.StorerKey, 
	 	                STOCKTAKESHEETPARAMETERS.Facility, ''
	 	         FROM STOCKTAKESHEETPARAMETERS (NOLOCK)
	 	         WHERE STOCKTAKESHEETPARAMETERS.StockTakeKey = LEFT(@c_sourcekey,10)
	 	         
	           IF ISNULL(RTRIM(@c_arcdbname),'') <> '' AND @@ROWCOUNT = 0
	           BEGIN
                SELECT @sql = 'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) ' +     
                + ' SELECT STOCKTAKESHEETPARAMETERS.StockTakeKey, STOCKTAKESHEETPARAMETERS.StorerKey, '     
                + '        STOCKTAKESHEETPARAMETERS.Facility, '''' '     
                + ' FROM '+RTRIM(@c_arcdbname)+'.dbo.STOCKTAKESHEETPARAMETERS STOCKTAKESHEETPARAMETERS (NOLOCK) '     
                + ' WHERE STOCKTAKESHEETPARAMETERS.StockTakeKey = LEFT(@c_sourcekey,10) '
   
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey      
             END
                          
	 	        -- IF EXISTS (SELECT TOP 1 1 FROM #TMP_REF)
	 	         SELECT TOP 1 @c_referencekey = Referencekey, @c_externreferencekey = Externreferencekey, 
	 	                  @c_externreferencetype = Externreferencetype, @c_remarks = remarks
	 	         FROM #TMP_REF
	 	     END
	 	    
	 	    UPDATE #TMP_ITRN WITH (ROWLOCK)
	 	    SET sourcetypedesc = ISNULL(@c_sourcetypedesc,''),
	 	        referencekey = ISNULL(@c_referencekey,''),
	 	        externreferencekey = ISNULL(@c_externreferencekey,''),
	 	        externreferencetype= ISNULL(@c_externreferencetype,''),
	 	        remarks = ISNULL(@c_remarks,'')
	 	    WHERE rowid = @n_rowid

          FETCH NEXT FROM C_ItemLoop INTO @n_rowid, @c_sourcekey, @c_sourcetype, @c_trantype2 
      END  
     
      CLOSE C_ItemLoop  
      DEALLOCATE C_ItemLoop      
       

      SET @d_Trace_EndTime =getdate()
      SET @c_Trace_Step2 = convert(varchar(22), @d_Trace_Step2, 120)
      SET @c_Trace_Step3 = convert(varchar(22), @d_Trace_Step3, 120)

       

      EXEC isp_InsertTraceInfo     
         @c_TraceCode = 'GetInvTrace',    
         @c_TraceName = 'isp_GetInvTrace',    
         @c_starttime = @d_Trace_StartTime,    
         @c_endtime = @d_Trace_EndTime,    
         @c_step1 = '',    
         @c_step2 = @c_Trace_Step2,    
         @c_step3 = @c_Trace_Step3,    
         @c_step4 = '',    
         @c_step5 = '',    
         @c_col1 = @c_Trace_Col1,     
         @c_col2 = @c_Trace_Col2,    
         @c_col3 = @c_Trace_Col3,    
         @c_col4 = @c_Trace_Col4,    
         @c_col5 = '',    
         @b_Success = 1,    
         @n_Err = 0,    
         @c_ErrMsg = '' 

	 	 	 	 	 
	 	 
	 	 SELECT Storerkey, Facility, Effectivedate, SourceTypeDesc, Trantype,
            Sku, FromLoc, ToLoc, FromID, ToID, Lot, Qty, 
            caseqty, ipqty, UOM, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
				Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,                            --(CS01)
				Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,                            --(CS01)
            referencekey, externreferencekey, externreferencetype, remarks, 
            AddWho, AddDate, EditWho, EditDate, itrnkey, '    '
     FROM #TMP_ITRN
     ORDER BY storerkey, facility, Adddate, sku, lot

     Truncate TABLE #TMP_ITRN

     DROP table  #TMP_ITRN


   END      
END

GO