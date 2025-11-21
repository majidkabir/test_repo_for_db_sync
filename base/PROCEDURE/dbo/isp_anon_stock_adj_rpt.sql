SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/            
/* Stored Proc: isp_anon_stock_adj_rpt                                     */            
/* Creation Date: 05-JUNE-2018                                             */            
/* Copyright: LF Logistics                                                 */            
/* Written by: CSCHONG                                                     */            
/*                                                                         */            
/* Purpose:WMS-5032-CN_HMCOS_Stock adjustment report                       */            
/*        :                                                                */            
/* Called By: r_anon_stock_adj_rpt                                         */            
/*          :                                                              */            
/* PVCS Version: 1.0                                                       */            
/*                                                                         */            
/* Data Modifications:                                                     */            
/*                                                                         */            
/* Updates:                                                                */            
/* Date         Author     Ver  Purposes                                   */        
/* 1/11/2018    Grick(G01) 1.0  Create temp table for podet to prevent     */      
/*                              Duplicate                                  */        
/***************************************************************************/            
CREATE PROC [dbo].[isp_anon_stock_adj_rpt]            
           @c_storerKey       NVARCHAR(10),            
           @c_FromDate        NVARCHAR(10),             
           @c_ToDate          NVARCHAR(10)             
            
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_NULLS ON            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   SET ANSI_WARNINGS ON           
            
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
            
   SET @n_StartTCnt = @@TRANCOUNT            
               
   SET @n_NoOfLine = 12            
            
   WHILE @@TRANCOUNT > 0            
   BEGIN            
      COMMIT TRAN            
   END            
               
    SET @c_arcdbname = ''            
               
    SELECT @c_arcdbname = NSQLValue FROM NSQLCONFIG (NOLOCK)            
    WHERE ConfigKey='ArchiveDBName'            
            
 SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'')             
   FROM NSQLCONFIG (NOLOCK)                 
   WHERE ConfigKey='DataMartServerDBName'              
                
      IF ISNULL(@c_DataMartServerDB,'') = ''            
      SET @c_DataMartServerDB = 'DATAMART'            
     
   IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.'             
 BEGIN            
      SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'              
   END             
                
            
            
     CREATE TABLE #TMP_ANADJRPT            
      (  RowID              INT IDENTITY (1,1) NOT NULL             
      , LOT                         NVARCHAR(50)   NULL  DEFAULT('')            
      ,  Pieces                      INT            NULL              
      ,  Original_Sales_Price        FLOAT          NULL                
      ,  Reason_code_for_adjustment  NVARCHAR(45)   NULL  DEFAULT('')            
      ,  Reason_descr                NVARCHAR(120)  NULL DEFAULT('')            
      ,  StartDate                   NVARCHAR(10)   NULL DEFAULT('')            
      ,  EndDate                     NVARCHAR(10)   NULL DEFAULT('')            
   ,  Total_Per_Lot               FLOAT NULL            
      )            
            
       CREATE TABLE #PODET           --G01      
      ( StorerKey  NVARCHAR(15) NULL            
      , Sku        NVARCHAR(20) NULL            
      , Lottable02 NVARCHAR(20) NULL            
      , UnitPrice  FLOAT NULL            
      )            
            
      SET @c_SQLSelect = ''            
     SET @c_SQLSelect = N' SELECT StorerKey, Sku, ISNULL(RTRIM(Lottable02),'''') AS Lottable02, MAX(ISNULL(UnitPrice,0)) AS UnitPrice '            
                         + ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ODS.PODetail WITH (NOLOCK) '            
                         + ' WHERE StorerKey = @c_StorerKey '            
                         + ' AND ISNULL(UnitPrice,0) > 0 '            
                         + ' GROUP BY StorerKey, Sku, ISNULL(RTRIM(Lottable02),'''') '            
            
     INSERT INTO #PODET (StorerKey, Sku, Lottable02, UnitPrice)            
     EXEC sp_executesql @c_SQLSelect,            
         N'@c_StorerKey NVARCHAR(15)',            
         @c_StorerKey                  
      
    SET @sqlinsert   = N'INSERT INTO #TMP_ANADJRPT ( '            
                + ' LOT,Pieces,Original_Sales_Price,Reason_code_for_adjustment,  '            
                 + ' Reason_descr,StartDate, EndDate,Total_Per_Lot) '            
                  
            
     SET @sqlselect =  N' SELECT DISTINCT ITRN.sku + SUBSTRING(ITRN.lottable02,7,6)+SUBSTRING(ITRN.lottable02,1,6) '            
                      + ',sum(itrn.qty),PODET.unitprice,ajd.ReasonCode,c.[Description],@c_FromDate,@c_todate,(sum(itrn.qty)*PODET.unitprice) '            
            
    SET @sqlfrom =  N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ITRN WITH (NOLOCK) '            
                    + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ADJUSTMENTDETAIL AS AJD WITH (NOLOCK) ON AJD.AdjustmentKey = SUBSTRING(ITRN.SourceKey,1,10) '            
        + ' AND AJD.AdjustmentLineNumber = SUBSTRING(ITRN.SourceKey,11,5) AND AJD.Lot=ITRN.Lot'            
        + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON LOTT.lot=AJD.Lot'            
        + ' JOIN #PODET PODET WITH (NOLOCK) ' --G01         
        + ' ON PODET.Lottable02=LOTT.Lottable02 AND ITRN.sku = PODET.sku'            
        + ' JOIN  ' + RTRIM(@c_DataMartServerDB) + 'ods.CODELKUP C WITH (NOLOCK) ON c.LISTNAME=''ADJREASON'' AND c.Code=ajd.ReasonCode '            
        + ' AND c.Storerkey=itrn.StorerKey '            
         
            
  SET @sqlwhere =N'WHERE itrn.TranType=''AJ'' '            
       + ' AND itrn.[Status]=''OK'' '            
       + ' AND itrn.StorerKey=@c_storerKey'            
       + ' AND convert(nvarchar(8),AJD.EditDate,112) >= @c_FromDate '            
       + ' AND convert(nvarchar(8),AJD.EditDate,112) <= @c_todate '            
       + ' GROUP BY ITRN.sku + SUBSTRING(ITRN.lottable02,7,6)+SUBSTRING(ITRN.lottable02,1,6) ,PODET.unitprice'            
       + ',ajd.ReasonCode,c.[Description] '--,LOTT.lottable02,(itrn.qty)            
       + ' HAVING sum(itrn.qty) <> 0 '            
              
            
  SET @sql = @sqlinsert + CHAR(13) + @sqlselect + CHAR(13) + @sqlfrom + CHAR(13) + @sqlwhere                                
   EXEC sp_executesql @sql,                                             
                    N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20)',             
                     @c_FromDate,@c_ToDate,@c_storerKey                   
      
 SET @sqlselect = ''            
 SET @sqlfrom  = ''            
 SET @sql = ''            
 SET @n_Uprice = 0            
            
            
/*    SET @sqlselect =  N'SELECT @n_Uprice = MAX(podet.UnitPrice) '            
                
  SET @sqlfrom =  N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ITRN WITH (NOLOCK) '            
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ADJUSTMENTDETAIL AS AJD WITH (NOLOCK) ON AJD.AdjustmentKey = SUBSTRING(ITRN.SourceKey,1,10) '            
        + ' AND AJD.AdjustmentLineNumber = SUBSTRING(ITRN.SourceKey,11,5) AND AJD.Lot=ITRN.Lot'            
        + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON LOTT.lot=AJD.Lot'            
        + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL PODET WITH (NOLOCK) ON PODET.Lottable02=LOTT.Lottable02'            
        SET @sqlwhere =N'WHERE itrn.TranType=''AJ'' '            
         + ' AND itrn.[Status]=''OK'' '            
       + ' AND itrn.StorerKey=@c_storerKey'            
       + ' AND convert(nvarchar(8),AJD.EditDate,112) >= @c_FromDate '            
       + ' AND convert(nvarchar(8),AJD.EditDate,112) <= @c_todate '            
               
                 
    SET @sql = @sqlselect + CHAR(13) + @sqlfrom + CHAR(13) + @sqlwhere              
                    
   EXEC sp_executesql @sql,                                             
                         N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20),@n_Uprice FLOAT OUTPUT',          
                         @c_FromDate,@c_ToDate,@c_storerKey, @n_Uprice OUTPUT                   
            
            
--select @sql            
--select @n_Uprice '@n_Uprice'            
            
 UPDATE #TMP_ANADJRPT             
 SET Original_Sales_Price = @n_Uprice            
    ,Total_Per_Lot =  (Pieces * @n_Uprice)            
 where StartDate = @c_FromDate            
 and EndDate = @c_todate            
*/            
 SET @n_GTPcs   = 0            
   SET @n_GTPLOT  = 0            
            
 SELECT @n_GTPcs  = SUM(Pieces)            
       ,@n_GTPLOT =SUM(Total_Per_Lot)            
   FROM #TMP_ANADJRPT            
            
 INSERT INTO #TMP_ANADJRPT (LOT,Pieces,Original_Sales_Price,Reason_code_for_adjustment,            
         Reason_descr,StartDate, EndDate,Total_Per_Lot)             
   VALUES('Total',@n_GTPcs,'','','','','',@n_GTPLOT)            
            
/*  OPEN CUR_RESULT               
                 
   FETCH NEXT FROM CUR_RESULT INTO @c_lot,@n_Pcs,@n_OriSalesPrice,@c_reasoncode,@c_lottable02,@c_polott02,@c_codedescr             
                 
   WHILE @@FETCH_STATUS <> -1              
   BEGIN                  
                
    IF ISNULL(@c_polott02,'') = ''            
    BEGIN            
     SET @n_ARHOriSalesPrice = 0            
     --SELECT @n_ARHOriSalesPrice = MAX(POD.unitprice)            
     --FROM RTRIM(@c_arcdbname)..PODETAIL PODET WITH (NOLOCK)             
                 
                 
                 
      SET @c_Sql = N'SELECT @n_ARHOriSalesPrice = MAX(POD.unitprice)'            
                 +  ' FROM ' + @c_arcdbname + 'dbo.PODETAIL PODET WITH (NOLOCK)'            
                 +  ' WHERE PODET.lottable02 = @c_lottable02'            
            
      SET @c_SqlParms = N'@c_lottable02        NVARCHAR(30)'              
                      + ',@n_ARHOriSalesPrice  FLOAT   OUTPUT'            
            
  
      EXEC sp_ExecuteSql  @c_Sql            
                        , @c_SqlParms            
        , @c_lottable02            
                        , @n_ARHOriSalesPrice      OUTPUT             
            
      SET @n_OriSalesPrice = @n_ARHOriSalesPrice            
            
     END            
            
            
                  
      VALUES (@c_lot,@n_Pcs,@n_OriSalesPrice,@c_reasoncode,@c_codedescr,@c_FromDate, @c_ToDate)     
               
  FETCH NEXT FROM CUR_RESULT INTO @c_lot,@n_Pcs,@n_OriSalesPrice,@c_reasoncode,@c_lottable02,@c_polott02,@c_codedescr                           
                 
    END            
*/            
            
  SELECT            
         LOT                                     
      ,  Pieces                                    
      ,  Original_Sales_Price                        
      ,  Reason_code_for_adjustment              
      ,  Reason_descr                            
      ,  StartDate                               
      ,  EndDate                   
      , Total_Per_Lot            
   FROM #TMP_ANADJRPT             
 Order by Rowid            
            
   WHILE @@TRANCOUNT < @n_StartTCnt            
   BEGIN            
      BEGIN TRAN            
   END            
END -- procedure 

GO