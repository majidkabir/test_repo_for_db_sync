SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_anon_stock_movement_rpt                             */  
/* Creation Date: 12-JUNE-2018                                          */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:WMS-5088-CN_HMCOS_Stock Movement Report                      */  
/*        :                                                             */  
/* Called By: r_anon_stock_movement_rpt                                 */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 18-9-2018    Grick     INC0394560- Result GoodReceive and Return     */  
/*                                    wrong (G01)                       */  
/* 26-9-2018    Grick               - Not able to display all the sku by*/
/*                                    orderkey(G02)                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_anon_stock_movement_rpt]  
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
         , @c_reasoncode        NVARCHAR(45)  
         , @c_codedescr         NVARCHAR(120)  
         , @c_lottable02        NVARCHAR(20)  
         , @c_polott02          NVARCHAR(20)  
         , @c_Sql               NVARCHAR(MAX)  
         , @c_SQLParms          NVARCHAR(4000)     
         , @n_qtyrec            FLOAT   
         , @n_salesprice        FLOAT   
   , @n_RTQty             INT  
   , @n_RTUP              FLOAT  
   , @n_RTprice           FLOAT   
         , @c_profitcenter1     NVARCHAR(80)  
         , @c_profitcenter2     NVARCHAR(80)  
         , @c_profitcenter3     NVARCHAR(80)  
         , @n_qtyshipped        FLOAT  
   , @c_OHUDF03           NVARCHAR(30)  
   , @c_RHUDF04           NVARCHAR(30)  
   , @c_shop              NVARCHAR(50)  
   , @n_PODUnitPrice      FLOAT  
   , @n_ARHPODUnitPrice   FLOAT  
   , @n_TTLSALES          FLOAT  
   , @n_TTLRTN            FLOAT  
   , @n_LFDCGRECV         FLOAT  
   , @n_STADJ             FLOAT  
   , @n_RTNINV            FLOAT  
   , @n_LFDCUP            FLOAT  
   , @n_LFDCRCQty         FLOAT  
   , @c_LFDCpolott02      NVARCHAR(20)  
   , @n_LFDCADJQty        FLOAT  
   , @n_LFDCADJANONQty    FLOAT  
   , @n_LFDCSADJUP        FLOAT  
   , @n_LFDCRTINVUP       FLOAT  
   , @c_LFDCADJlott02     NVARCHAR(20)  
   , @c_LFDCRTINVlott02   NVARCHAR(20)  
   , @n_LFDCADJPrice      FLOAT  
   , @n_LFDCRTINVPrice    FLOAT  
   , @c_DataMartServerDB NVARCHAR(120)  
   , @sql                NVARCHAR(MAX)  
         , @sqlinsert          NVARCHAR(MAX)  
         , @sqlselect          NVARCHAR(MAX)  
         , @sqlfrom            NVARCHAR(MAX)  
         , @sqlwhere           NVARCHAR(MAX)   
  
  
   SET @n_StartTCnt = @@TRANCOUNT  
     
   SET @n_NoOfLine = 12  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
     
    SET @c_arcdbname = ''  
  SET @c_shop = ''  
     
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
      
    SELECT @c_profitcenter1 =  ISNULL(c.UDF01,''),  
           @c_profitcenter2 =  ISNULL(c.UDF02,''),  
           @c_profitcenter3 =  ISNULL(c.UDF03,'')  
    FROM codelkup c (NOLOCK)  
    WHERE c.LISTNAME='COSSMR'  
    AND c.code = '1' AND c.Storerkey='18441'  
  
  
  CREATE TABLE #TEMP_LFDCADJ  
  (LFDCADJQTY       INT,  
   LFDCADJUP        FLOAT,  
   ADJRC            NVARCHAR(80)  
  )  
  
   CREATE TABLE #TEMP_DMITRN  
  (Key01           NVARCHAR(50),  
  Key02            NVARCHAR(10),  
  Sourcekey        NVARCHAR(50),  
  Storerkey        NVARCHAR(20)  )  
  
   CREATE TABLE #TMP_ANASTMOVHRPT  
      (  RowID                       INT IDENTITY (1,1) NOT NULL   
      , SHOP                        NVARCHAR(50)   NULL  DEFAULT('')  
      ,  SKU                         NVARCHAR(20)   NULL  DEFAULT('')  
      ,  SALES                       FLOAT          NULL    
      ,  Profit_Center               NVARCHAR(50)   NULL  DEFAULT ('')  
      ,  StartDate                   NVARCHAR(10)   NULL  DEFAULT('')  
      ,  EndDate                     NVARCHAR(10)   NULL  DEFAULT('')  
      ,  SYSDATE                     NVARCHAR(6)    NULL  DEFAULT ('')  
      )  
  
  
   CREATE TABLE #TMP_ANASTMOVRPT  
      (  RowID                       INT IDENTITY (1,1) NOT NULL   
      , SHOP                        NVARCHAR(50)   NULL  DEFAULT('')  
      ,  ALLEGAT                     FLOAT          NULL    
      ,  SALES                       FLOAT          NULL    
      ,  [RETURN]                    FLOAT          NULL  
      ,  Stock_Adjustment            NVARCHAR(20)   NULL  DEFAULT('')  
      ,  Profit_Center               NVARCHAR(50)   NULL  DEFAULT ('')  
      ,  StartDate                   NVARCHAR(10)   NULL  DEFAULT('')  
      ,  EndDate                     NVARCHAR(10)   NULL  DEFAULT('')  
      ,  SYSDATE                     NVARCHAR(6)    NULL  DEFAULT ('')  
  ,  ANONRTNINV                  FLOAT          NULL  
      )  
  
  
 --select getdate() 'starttime'    
 --set @sqlinsert   = N'INSERT INTO #TMP_ANASTMOVRPT ('  
 --                   + 'SHOP,ALLEGAT,SALES,[RETURN],Stock_Adjustment,'  
 --                 + 'Profit_Center,StartDate,EndDate,SYSDATE,ANONRTNINV)'  
  
  --DECLARE CUR_OSITE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
  --print 1  
    SET @sqlselect =  N' SELECT CASE WHEN ord.USERDEFINE03 = ''Officalsite'' THEN ''COS ONLINE'' ELSE ''TMALLCN'' END ,'  
                    + ' od.sku,(od.shippedqty*ISNULL(podet.UnitPrice,0)),'  
        + ' CASE WHEN ord.USERDEFINE03 = ''Officalsite'' THEN @c_profitcenter1 ELSE @c_profitcenter2 END,'   
        + ' @c_FromDate,@c_ToDate,convert(nvarchar(6),GETDATE(),112) '  
  
   SET @sqlfrom =  N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORD WITH (NOLOCK) '  
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERDETAIL OD WITH (nolock) ON OD.Orderkey=ORD.OrderKey '  
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PICKDETAIL PD WITH (NOLOCK) ON pd.OrderKey=ORD.OrderKey AND PD.sku = OD.sku '--AND pd.OrderLineNumber = od.OrderLineNumber  
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON lott.lot=PD.lot and lott.sku=pd.sku'  
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL AS PODET WITH (NOLOCK) ON PODET.Lottable02=lott.Lottable02 and PODET.sku=lott.sku'  
  
  SET  @sqlwhere = N' WHERE ord.[Status]=''9'' AND ord.USERDEFINE03 IN (''Officalsite'',''TMALLCN'') '  
        + ' AND ord.StorerKey=@c_storerKey'  
        + ' AND convert(nvarchar(10),ord.EditDate,112) >= @c_FromDate '  
        + ' AND convert(nvarchar(10),ord.EditDate,112) <= @c_ToDate '  
        + ' AND ISNULL(podet.UnitPrice,0) <> 0 '  
        + ' AND ISNULL(PODET.Lottable02,'''') <> '''' '  
        +'  GROUP BY ord.USERDEFINE03,(od.shippedqty*ISNULL(podet.UnitPrice,0)),od.sku,od.OrderKey'  --G02
        + ' ORDER BY ord.USERDEFINE03 '  
  
    SET @sql = @sqlselect + CHAR(13) + @sqlfrom + CHAR(13) + @sqlwhere    
     INSERT INTO #TMP_ANASTMOVHRPT (SHOP,SKU,SALES,Profit_Center,StartDate,EndDate,SYSDATE)       
   EXEC sp_executesql @sql,                                   
                    N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_profitcenter1  NVARCHAR(80),@c_profitcenter2  NVARCHAR(80),@c_storerKey NVARCHAR(20)',   
                     @c_FromDate,@c_ToDate,@c_profitcenter1,@c_profitcenter2,@c_storerKey              
    
  --print '2'  
    --select @sql '@sql'  
  
  --select * from #TMP_ANASTMOVHRPT  
  
  INSERT INTO #TMP_ANASTMOVRPT (SHOP,ALLEGAT,SALES,[RETURN],Stock_Adjustment,  
                  Profit_Center,StartDate,EndDate,SYSDATE,ANONRTNINV)  
  
      SELECT SHOP,'',SUM(SALES),'','',Profit_Center,StartDate,EndDate,SYSDATE,''  
  FROM #TMP_ANASTMOVHRPT  
  GROUP BY SHOP,Profit_Center,StartDate,EndDate,SYSDATE  
  
  set @sqlinsert = ''  
  SET @sqlselect = ''  
  SET @sqlfrom = ''  
  SET @sql = ''  
  SET @n_RTprice = 0   
  
 -- select getdate() 'starttime'  
  
  --      SET @sqlselect =  N'SELECT @n_RTprice = sum(rd.QtyReceived *ISNULL(podet.UnitPrice,0)),@c_RHUDF04 = REC.userdefine04 '  
  --  SET @sqlfrom =  N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ITRN WITH (NOLOCK) '   
  --                 + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPTDETAIL RD WITH (nolock) '  
  --       + ' ON rd.receiptkey = left(itrn.sourcekey,10) and rd.receiptlinenumber = right(itrn.sourcekey,5) '  
  --                 + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPT REC WITH (NOLOCK) ON rd.ReceiptKey=rec.ReceiptKey '  
  --                -- + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON lott.Lottable02=Rd.Lottable02'  
  --                 + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL AS PODET WITH (NOLOCK) ON PODET.Lottable02=RD.Lottable02 and PODET.sku = RD.sku'  
  --                 + ' WHERE itrn.status=''OK''  '  
  --                 + ' AND rec.ASNStatus=''9'' AND rec.DOCTYPE=''R''  '  
  --                 + ' AND rec.userdefine04 in (''Officalsite'',''TMALLCN'') '  
  --                 + ' AND rec.StorerKey=@c_storerKey '  
  --                 + ' AND convert(nvarchar(10),itrn.EditDate,112) >= @c_FromDate '  
  --       + ' AND convert(nvarchar(10),itrn.EditDate,112) <= @c_ToDate '  
  --       + ' AND ISNULL(podet.UnitPrice,0) <> 0 '  
  --                 + ' GROUP BY REC.userdefine04'  
  --                 + ' ORDER BY REC.userdefine04 '  
  
    
  --SET @sql = @sqlselect + CHAR(13) + @sqlfrom --+ CHAR(13) + @sqlwhere    
          
  -- EXEC sp_executesql @sql,                                   
  --                  N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20),@n_RTprice FLOAT OUTPUT,@c_RHUDF04 NVARCHAR(80) OUTPUT',   
  --                   @c_FromDate,@c_ToDate,@c_storerKey,@n_RTprice OUTPUT ,@c_RHUDF04 OUTPUT        
    
   
 ----select @sql '@sql'  
 --SET @c_shop = ''  
 --IF @c_RHUDF04 ='Officalsite'  
 -- BEGIN  
 --   SET @c_shop = 'COS ONLINE'  
 -- END  
 -- ELSE  
 -- BEGIN  
 --    SET @c_shop = 'TMALLCN'  
 -- END  
  
 -- --select * from #TMP_ANASTMOVRPT  
 -- --select @c_RHUDF04 '@c_RHUDF04',@c_shop '@c_shop',@n_RTprice '@n_RTprice'  
  
 -- IF @c_shop = 'COS ONLINE'  
 -- BEGIN  
 --   UPDATE #TMP_ANASTMOVRPT  
 --   SET [RETURN] = @n_RTprice  
 --   WHERE SHOP = 'COS ONLINE'  
 -- END  
 -- ELSE IF @c_shop = 'TMALLCN'  
 -- BEGIN  
 --    UPDATE #TMP_ANASTMOVRPT  
 --  SET [RETURN] = @n_RTprice  
 --  WHERE SHOP = 'TMALLCN'  
 --  END  
  
    SET @sqlselect = N'DECLARE C_ViewRTprice CURSOR FAST_FORWARD READ_ONLY FOR'                 --G01  
        +' SELECT sum(rd.QtyReceived *ISNULL(podet.UnitPrice,0)),REC.userdefine04 '    
        +' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ITRN WITH (NOLOCK) '     
                    + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPTDETAIL RD WITH (nolock) '    
                    + ' ON rd.receiptkey = left(itrn.sourcekey,10) and rd.receiptlinenumber = right(itrn.sourcekey,5) '    
                    + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPT REC WITH (NOLOCK) ON rd.ReceiptKey=rec.ReceiptKey '    
                  -- + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON lott.Lottable02=Rd.Lottable02'    
                    + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL AS PODET WITH (NOLOCK) ON PODET.Lottable02=RD.Lottable02 and PODET.sku = RD.sku'    
                    + ' WHERE itrn.status=''OK''  '    
                    + ' AND rec.ASNStatus=''9'' AND rec.DOCTYPE=''R''  '    
                    + ' AND rec.userdefine04 in (''Officalsite'',''TMALLCN'') '    
                    + ' AND rec.StorerKey=@c_storerKey '    
                    + ' AND convert(nvarchar(10),itrn.EditDate,112) >= @c_FromDate '    
                    + ' AND convert(nvarchar(10),itrn.EditDate,112) <= @c_ToDate '    
                    + ' AND ISNULL(podet.UnitPrice,0) <> 0 '    
                    + ' GROUP BY REC.userdefine04'    
                    + ' ORDER BY REC.userdefine04 '    
     
      
   SET @sqlfrom =  N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20)'     
            
    EXEC sp_executesql @sqlselect, @sqlfrom,@c_FromDate,@c_ToDate,@c_storerKey    
    
  OPEN C_ViewRTprice  
   FETCH NEXT FROM C_ViewRTprice INTO @n_RTprice,@c_RHUDF04  
   WHILE @@FETCH_STATUS <> -1     
    BEGIN    
     SET @c_shop = ''    
     IF @c_RHUDF04 ='Officalsite'    
        BEGIN    
        -- SET @c_shop = 'COS ONLINE'  
        UPDATE #TMP_ANASTMOVRPT    
        SET [RETURN] = @n_RTprice    
          WHERE SHOP = 'COS ONLINE'    
       END    
     ELSE    
       BEGIN    
       --SET @c_shop = 'TMALLCN'  
       UPDATE #TMP_ANASTMOVRPT    
       SET [RETURN] = @n_RTprice 
       WHERE SHOP = 'TMALLCN'        
     END   
     FETCH NEXT FROM C_ViewRTprice INTO @n_RTprice,@c_RHUDF04   
   END -- WHILE @@FETCH_STATUS <> -1  
   CLOSE C_ViewRTprice    
   DEALLOCATE C_ViewRTprice   
     
  SET @n_RTprice='0'  --G01  
  
  IF NOT EXISTS(SELECT 1 FROM #TMP_ANASTMOVRPT  
                where shop ='COS ONLINE')  
   BEGIN  
  INSERT INTO #TMP_ANASTMOVRPT  
 (  
  -- RowID -- this column value is auto-generated  
  SHOP,  
  ALLEGAT,  
  SALES,  
  [RETURN],  
  Stock_Adjustment,  
  Profit_Center,  
  StartDate,  
  EndDate,  
  SYSDATE,  
  ANONRTNINV  
 )  
 VALUES ('COS ONLINE','','',@n_RTprice,'',@c_profitcenter1,@c_FromDate,@c_ToDate,convert(nvarchar(6),GETDATE(),112),'')  
  
 END  
   
  
 IF NOT EXISTS(SELECT 1 FROM #TMP_ANASTMOVRPT  
                where shop ='TMALLCN')  
   BEGIN  
  INSERT INTO #TMP_ANASTMOVRPT  
 (  
  -- RowID -- this column value is auto-generated  
  SHOP,  
  ALLEGAT,  
  SALES,  
  [RETURN],  
  Stock_Adjustment,  
  Profit_Center,  
  StartDate,  
  EndDate,  
  SYSDATE,  
  ANONRTNINV  
 )  
 VALUES ('TMALLCN','','',@n_RTprice,'',@c_profitcenter2,@c_FromDate,@c_ToDate,convert(nvarchar(6),GETDATE(),112),'')  
  
 END  
  
   set @sqlinsert = ''  
  SET @sqlselect = ''  
  SET @sqlfrom = ''  
  SET @sql = ''  
  SET @n_LFDCGRECV  = 0   
  
  --select getdate() 'starttime'  
  
  --SET @sqlinsert = N'INSERT INTO  #TEMP_LFDCRD(LFDCRDQTY,LFDCRDUP)'   
      --CC  
    SET @sqlselect = N' SELECT @n_LFDCGRECV = sum(RD.QtyReceived*ISNULL(podet.UnitPrice,0))'  
            --   + ' INTO #TEMP_LFDCRD '  
               + ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPT REC WITH (NOLOCK) '  
               + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPTDETAIL RD WITH (NOLOCK) ON RD.Receiptkey = REC.receiptkey '  
           --    + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON lott.Lottable02=Rd.Lottable02'  
               + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL AS PODET WITH (NOLOCK) ON PODET.Lottable02=RD.Lottable02 AND PODET.sku=RD.sku AND PODET.PoKey=RD.PoKey AND PODET.POlinenumber=RD.POlinenumber' --G01  
               + ' WHERE REC.storerkey = @c_storerkey '  
               + ' AND rec.ASNStatus=''9'' AND rec.DOCTYPE=''A'' '  
               + ' AND convert(nvarchar(10),REC.EditDate,112) >= @c_FromDate '  
       + ' AND convert(nvarchar(10),REC.EditDate,112) <= @c_ToDate '  
       + ' AND ISNULL(podet.UnitPrice,0) <> 0 '  
        
   SET @sql = @sqlselect --+ CHAR(13) + @sqlfrom --+ CHAR(13) + @sqlwhere    
      
  -- INSERT INTO  #TEMP_LFDCRD(LFDCRDQTY,LFDCRDUP)      
   EXEC sp_executesql @sql,                                   
                    N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20),@n_LFDCGRECV FLOAT OUTPUT',   
                     @c_FromDate,@c_ToDate,@c_storerKey, @n_LFDCGRECV OUTPUT    
    
  --SELECT @n_LFDCGRECV = (sum(LFDCRDQTY) * MAX(LFDCRDUP))  
  --FROM #TEMP_LFDCRD  
         
  --select @sql '@sql'  
  SET @sqlinsert = ''  
  SET @sqlselect = ''  
  SET @sqlfrom = ''  
  SET @sql = ''  
  SET @n_LFDCADJPrice  = 0   
  SET @n_LFDCRTINVPrice  = 0   
  
         
     -- select getdate() 'starttime'  
  
   -- SET @sqlinsert=N'INSERT INTO #TEMP_LFDCADJ (LFDCADJQTY,LFDCADJUP)'  
  
   SET @sqlselect = ''  
   SET @sqlselect = N'SELECT left(itrn.sourcekey,10) as key01,right(itrn.sourcekey,5) key02 ,itrn.sourcekey as sourcekey,itrn.storerkey as storerkey'  
                    + ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ITRN WITH (NOLOCK)  '  
        + ' WHERE itrn.storerkey = @c_storerkey '   
                  + ' AND itrn.status=''OK'' '   
                  + ' AND itrn.trantype=''AJ'' '  
                --  + ' AND ADJDET.reasoncode not in (''Anonyup'') '  
                  + ' AND convert(nvarchar(10),ITRN.EditDate,112) >= @c_FromDate '  
            + ' AND convert(nvarchar(10),ITRN.EditDate,112) <= @c_ToDate '  
        +'  and sourcetype like ''%AdjustmentDetail%'' '   
  
       SET @sql = @sqlselect  
  
      INSERT INTO  #TEMP_DMITRN (Key01,Key02,Sourcekey,Storerkey)  
  EXEC sp_executesql @sql,                                   
                    N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20)',--,@n_LFDCADJPrice FLOAT OUTPUT',   
                     @c_FromDate,@c_ToDate,@c_storerKey  
        
  --select * from #TEMP_DMITRN  
  SET @sqlselect = ''  
  
    SET @sqlselect = N' SELECT ADJDET.Qty as LFDCADJQty,ISNULL(podet.UnitPrice,0) as LFDCPUP,ADJDET.reasoncode as ADJRC '  
                  --+ ' INTO TEMP_LFDCADJ'  
                 -- + ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ITRN WITH (NOLOCK)  '  
        + ' FROM  #TEMP_DMITRN ITRN WITH (NOLOCK) '  
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.Adjustmentdetail ADJDET WITH (nolock) '  
       -- + ' ON ADJDET.AdjustmentKey = left(itrn.sourcekey,10) AND ADJDET.AdjustmentLineNumber = right(itrn.sourcekey,5) '  
       + ' ON ADJDET.AdjustmentKey = ITRN.Key01 AND ADJDET.AdjustmentLineNumber = ITRN.Key02 '  
               --   + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON lott.Lottable02=ADJDET.Lottable02 '  
                  + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL AS PODET WITH (NOLOCK) ON PODET.Lottable02=ADJDET.Lottable02 and PODET.sku = ADJDET.SKU'  
            --      + ' WHERE itrn.storerkey = @c_storerkey '   
            --      + ' AND itrn.status=''OK'' '   
            --      + ' AND itrn.trantype=''AJ'' '  
            --    --  + ' AND ADJDET.reasoncode not in (''Anonyup'') '  
            --      + ' AND convert(nvarchar(10),ITRN.EditDate,112) >= @c_FromDate '  
            --+ ' AND convert(nvarchar(10),ITRN.EditDate,112) <= @c_ToDate '  
        + ' WHERE ISNULL(podet.UnitPrice,0) <> 0 '  
        
        
  SET @sql = @sqlselect --+ CHAR(13) + @sqlfrom --+ CHAR(13) + @sqlwhere   
    
  INSERT INTO #TEMP_LFDCADJ (LFDCADJQTY,LFDCADJUP,ADJRC)  
      --EXEC ( @c_ExecStatements )          
   EXEC sp_executesql @sql,                                   
                    N'@c_FromDate NVARCHAR(10),@c_ToDate NVARCHAR(10),@c_storerKey NVARCHAR(20)',--,@n_LFDCADJPrice FLOAT OUTPUT',   
                     @c_FromDate,@c_ToDate,@c_storerKey--, @n_LFDCADJPrice OUTPUT  
         
      -- select * from #TEMP_LFDCADJ    
  
      SELECT @n_LFDCADJPrice = sum(LFDCADJQty*LFDCADJUP)  
  FROM #TEMP_LFDCADJ  
  where ADJRC  not in ('Anonyup')   
  
  SELECT @n_LFDCRTINVPrice =  sum(LFDCADJQty*LFDCADJUP)  
  FROM #TEMP_LFDCADJ  
  where ADJRC in ('Anonyup')   
  
      --select @sql '@sql'  
      SET @sqlinsert = ''  
  SET @sqlselect = ''  
  SET @sqlfrom = ''  
  SET @sql = ''  
       
             
  SET  @n_TTLSALES = 0  
  SELECT @n_TTLSALES = SUM(SALES)  
  FROM #TMP_ANASTMOVRPT  
  WHERE shop in ('COS ONLINE','TMALLCN')  
  
  SET @n_TTLRTN  = 0  
  SELECT @n_TTLRTN = SUM([RETURN])  
  FROM #TMP_ANASTMOVRPT  
  WHERE shop in ('COS ONLINE','TMALLCN')        
  
  INSERT INTO #TMP_ANASTMOVRPT  
 (  
  -- RowID -- this column value is auto-generated  
  SHOP,  
  ALLEGAT,  
  SALES,  
  [RETURN],  
  Stock_Adjustment,  
  Profit_Center,  
  StartDate,  
  EndDate,  
  SYSDATE,  
  ANONRTNINV  
 )  
  VALUES(  
    'LF-DC',@n_LFDCGRECV,@n_TTLSALES,@n_TTLRTN,@n_LFDCADJPrice,  
  @c_profitcenter3,@c_FromDate,@c_ToDate,convert(nvarchar(6),GETDATE(),112),@n_LFDCRTINVPrice  
   )  
   
  
   SELECT *  
   FROM #TMP_ANASTMOVRPT  
   ORDER BY RowID  
  
 --DROP TABLE #TEMP_LFDCADJ  
 --DROP TABLE #TEMP_LFDCRD  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END -- procedure  

GO