SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* SP: isp_Wyeth_IQC_Export                                             */  
/* Creation Date: 19th Aug 2005                                         */  
/* Copyright: IDS                                                       */  
/* Written by: Vicky                                                    */  
/*                                                                      */  
/* Purpose: IDSHK Wyeth IQC Export                                      */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: DTS Interface                                             */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */   
/*                                                                      */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 06-Oct-2005  Shong         New Criteria for Storerkey = 11313        */  
/* 10-Oct-2005  Vicky         New Criteria for Storerkey = 11312        */    
/* 20-July-2006 Vicky         New Criteria for Storerkey = 11312 &      */      
/*                            Storerkey = 11313 (SOS#54522)             */                                                       
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Wyeth_IQC_Export](  
        @c_SourceDBName NVARCHAR(20)  
       ,@c_StorerKey    NVARCHAR(15) -- 11312  
       ,@c_Storerkey1   NVARCHAR(15) -- 11313  
       ,@b_Success    int   OUTPUT  
       ,@n_err        int   OUTPUT  
       ,@c_errmsg       NVARCHAR(250) OUTPUT   
     
)  
AS  
BEGIN  
 DECLARE @c_QCkey           NVARCHAR(10)  
   , @c_ExternReceiptKey NVARCHAR(20)  
   , @c_ReceiptLineNumber NVARCHAR(5)  
   , @c_BatchNo        NVARCHAR(10)  
   , @n_HdrBatchLineNumber int  
   , @n_DetBatchLineNumber int  
   , @n_RowId           int  
   , @n_DetCounter     int  
   , @n_continue         int  
         , @n_starttcnt        int  -- Holds the current transaction count    
   , @b_debug           int  
   , @n_counter        int  
   , @c_ExecStatements   nvarchar(4000)  
         , @c_astorerkey         NVARCHAR(15)  
         , @n_cnthdtrans         int  
         , @n_cntdetrans         int  
         , @c_QClineno           NVARCHAR(5)     
         , @c_reason             NVARCHAR(5)  
         , @c_fromfacility       NVARCHAR(5)  
         , @c_tofacility         NVARCHAR(5)  
         , @c_toloc              NVARCHAR(10)   
         , @c_fromloc            NVARCHAR(10)  
         , @c_tohostwhcode       NVARCHAR(10)  
         , @c_fromhostwhcode     NVARCHAR(10)  
  
 SET NOCOUNT ON  
  
   SELECT @n_starttcnt = @@TRANCOUNT   
  
 SELECT @c_SourceDBName = RTRIM(@c_SourceDBName)  
  
 CREATE TABLE [##TempWyIQC] (  
      [Key1] [varchar] (10) NULL ,  
      [TransmitLogKey] [varchar] (10) NULL ,  
        [Key3] [varchar] (10) NULL ,  
        [Reason] [varchar] (5) NULL ,  
        [FromFacility] [varchar] (5) NULL ,  
        [ToFacility] [varchar] (5) NULL ,  
        [FromLoc] [varchar] (10) NULL ,  
        [ToLoc] [varchar] (10) NULL ,  
        [QCLineNo] [varchar] (5) NULL,  
        [RowId] [int] IDENTITY (1, 1) NOT NULL )  
  
  
   SELECT @b_debug = 0  
 SELECT @b_success = 0  
 SELECT @n_continue = 1  
  
 SELECT @c_ExecStatements = ''  
  
 -- Retrieve QCKey and TransmitLogKey from TransmitLog3 table,  
 SELECT @c_ExecStatements = N'INSERT INTO ##TempWyIQC (Key1, TransmitLogKey, Key3, Reason, FromFacility, ToFacility, '  
                            + 'FromLoc, ToLoc, QCLineNo)  '  
               + 'SELECT TransmitLog3.Key1, TransmitLog3.TransmitLogKey, TransmitLog3.Key3, Inventoryqc.Reason,'  
                            + 'Inventoryqc.From_facility, Inventoryqc.To_Facility, '  
                            + 'Inventoryqcdetail.FromLoc, Inventoryqcdetail.ToLoc, Inventoryqcdetail.QCLineNo '   
              + 'FROM ' + RTRIM(@c_SourceDBName) + '..TransmitLog3 TransmitLog3 (NOLOCK) '  
                            + 'JOIN ' + RTRIM(@c_SourceDBName) + '..Inventoryqc Inventoryqc (NOLOCK) '  
                            + 'ON (Inventoryqc.QC_Key = Transmitlog3.Key1 AND Inventoryqc.Storerkey = Transmitlog3.Key3) '  
                            + 'JOIN ' + RTRIM(@c_SourceDBName) + '..Inventoryqcdetail Inventoryqcdetail (NOLOCK) '  
                            + 'ON (Inventoryqc.QC_Key = Inventoryqcdetail.QC_Key AND Inventoryqc.Storerkey = Inventoryqcdetail.Storerkey) '  
              + 'WHERE TransmitLog3.Tablename = "IQCLOG" '    
              + 'AND TransmitLog3.TransmitFlag = "1" '  
                            + 'AND Inventoryqcdetail.Status = "9" '   
              + 'AND TransmitLog3.Key3 in ( N''' + RTRIM(@c_StorerKey) + '''' + ' , N''' + RTRIM(@c_StorerKey1) + '''' + ')'  
              + 'ORDER BY TransmitLog3.Key1, TransmitLog3.TransmitLogKey, Key3, QCLineNo'  
  
             EXEC sp_executesql @c_ExecStatements   
  
        SELECT @c_QCkey = ''   
        SELECT @n_counter = 0  
        SELECT @n_RowId = 0  
        SELECT @n_DetCounter = 0  
  
 -- Get BatchNo: YYMMDDHHMM  
 SELECT @c_BatchNo = CONVERT(CHAR(6), GetDate(), 12) +   
                 SUBSTRING(CONVERT(CHAR(8), GetDate(), 8), 1,2) +  
                 SUBSTRING(CONVERT(CHAR(8), GetDate(), 8), 4,2)  
  
   SELECT @n_HdrBatchLineNumber = 0  
   SELECT @n_DetBatchLineNumber = 0  
  
 WHILE (@n_continue=1) -- Loop for QCKey  
 BEGIN  
  
      SELECT @n_RowId = MIN(RowId)  
    FROM ##TempWyIQC (NOLOCK)  
   WHERE RowId > @n_RowId  
  
  IF  @@ROWCOUNT = 0 OR @n_RowId = 0 OR @n_RowId IS NULL  
  BREAK  
  
  SELECT @c_reason = reason,  
             @c_astorerkey = Key3,  
             @c_fromfacility = FromFacility,  
             @c_tofacility = ToFacility,  
             @c_toloc = ToLoc,  
             @c_fromloc = FromLoc,  
             @c_QCKey = Key1,  
             @c_QClineno = QCLineNo  
    FROM ##TempWyIQC (NOLOCK)  
   WHERE RowID = RTRIM(@n_RowId)  
  
  
           CREATE TABLE [#TmpToLoc] (  
                      [HostWhCode] [varchar] (10) NULL,  
                  [ToLoc] [varchar] (10) NULL ,  
                      [QCLineNo] [varchar] (5) NULL )  
  
           SELECT @c_ExecStatements = ''  
  
         SELECT @c_ExecStatements = N'INSERT INTO #TmpToLoc (HostWhCode, ToLoc, QCLineNo) '  
               + 'SELECT Loc.HostWhCode, N''' + RTRIM(@c_toloc) + ''', N''' +  RTRIM(@c_QClineno) + ''''  
               + 'FROM ' + RTRIM(@c_SourceDBName) + '..Loc Loc (NOLOCK) '  
               + 'WHERE Loc.Loc = N''' + RTRIM(@c_toloc) + ''''    
  
                EXEC sp_executesql @c_ExecStatements   
  
                    
                CREATE TABLE [#TmpFromLoc] (  
                         [HostWhCode] [varchar] (10) NULL,  
                      [FromLoc] [varchar] (10) NULL ,  
                         [QCLineNo] [varchar] (5) NULL )  
  
                SELECT @c_ExecStatements = ''  
  
               SELECT @c_ExecStatements = N'INSERT INTO #TmpFromLoc (HostWhCode, FromLoc, QCLineNo) '  
               + 'SELECT Loc.HostWhCode, N''' + RTRIM(@c_fromloc) + ''', N''' +  RTRIM(@c_QClineno) + ''''  
               + 'FROM ' + RTRIM(@c_SourceDBName) + '..Loc Loc (NOLOCK) '  
               + 'WHERE Loc.Loc = N''' + RTRIM(@c_fromloc) + ''''    
  
                    EXEC sp_executesql @c_ExecStatements   
  
   
                SELECT @c_tohostwhcode = HostWhCode                 
                FROM #TmpToLoc (NOLOCK)  
                WHERE QCLineNo = @c_QClineno  
  
  
                SELECT @c_fromhostwhcode = HostWhCode                 
                FROM #TmpFromLoc (NOLOCK)  
                WHERE QCLineNo = @c_QClineno  
  
                DROP TABLE #TmpToLoc  
                DROP TABLE #TmpFromLoc  
                 
                IF @b_debug = 1  
                BEGIN  
                  SELECT '@c_tohostwhcode', @c_tohostwhcode  
                  SELECT '@c_fromhostwhcode', @c_fromhostwhcode  
                END  
  
              IF @b_debug = 1  
              BEGIN  
               SELECT 'Key1 from TransmitLog3'  
               SELECT @c_QCkey + ' / ' + CONVERT(CHAR(10), @n_counter)  
               SELECT @c_QClineno + '   QCLineNo'   
               SELECT Convert(char(2), @n_RowId) + '  RowID'  
                 
              END  
  
       IF @b_debug = 1 SELECT 'Started WYIQC...'  
  
  -- Insert into header table  
  IF NOT EXISTS (SELECT 1 FROM WYIQC (NOLOCK) WHERE QC_Key = RTRIM(@c_QCkey) and QCLineno = RTRIM(@c_QClineno))  
  BEGIN  
   
 -- Count detail batch number and total detail lines   
   SELECT @n_DetBatchLineNumber = @n_DetBatchLineNumber + 1  
         SELECT @n_DetCounter = @n_DetCounter + 1  
  
         BEGIN TRAN  
  
         IF @c_astorerkey = @c_StorerKey -- 11312  
         BEGIN  
  
          IF RTRIM(@c_reason) = 'IM' AND RTRIM(@c_fromfacility) = '1171' AND RTRIM(@c_tofacility) = '1106'  
          BEGIN  
                       
    SELECT @c_ExecStatements = ''     
  
    SELECT @c_ExecStatements = N'INSERT INTO WYIQC (QC_Key, Reason, '  
                                     + 'Storerkey, From_Facility, To_Facility, QCLineNo, Sku, '  
                                     + 'Qty, UOM, FromLoc, ToLoc, FromHostWHCode, ToHostWHCode, IQCDate, '  
                                     + 'Batch, BatchLineNumber, Action, ProcessSource, ProcessDestination ) '  
                                     + 'SELECT N''' + RTRIM(@c_QCkey) + ''', '  
                                     + 'INVENTORYQC.Reason, '  
                                     + 'INVENTORYQC.Storerkey, '  
                                     + 'INVENTORYQC.From_Facility, '  
                                     + 'INVENTORYQC.To_Facility, '  
                                     + 'INVENTORYQCDETAIL.QCLineNo, '  
                                     + 'INVENTORYQCDETAIL.Sku, '  
                                     + 'INVENTORYQCDETAIL.Qty, '  
                                     + 'ISNULL(PACK.PackUOM3,"EA"), '  
                                     + 'INVENTORYQCDETAIL.FromLoc, '  
                                     + 'INVENTORYQCDETAIL.ToLoc, '  
                                     + 'CASE WHEN INVENTORYQC.From_Facility = "1171" THEN (SELECT LOC.HOSTWHCODE FROM ' + RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) '  
                                     + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) ON (INVENTORYQC.From_Facility = LOC.Facility) '  
                                     + 'WHERE From_facility = N''' + RTRIM(@c_fromfacility) + ''' '  
                                     + 'AND LOC.Loc = N'''+RTRIM(@c_fromloc) + ''' AND INVENTORYQC.QC_Key = N''' +RTRIM(@c_QCKey) + ''') ELSE '' '' END,  '  
                                     + 'CASE WHEN INVENTORYQC.To_Facility = ''1171'' THEN (SELECT LOC.HOSTWHCODE FROM ' + RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) '  
                                     + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) ON (INVENTORYQC.To_Facility = LOC.Facility) '  
                                     + 'WHERE To_facility = N''' + RTRIM(@c_tofacility) + ''' '  
                                     + 'AND LOC.Loc = N'''+RTRIM(@c_toloc) + ''' AND INVENTORYQC.QC_Key = N''' +RTRIM(@c_QCKey) + ''' ) ELSE '' '' END,  '  
             + 'Convert(char(8),INVENTORYQC.AddDate,112), '  
             + 'N''' + @c_BatchNo + ''', '  
             + CAST(@n_DetBatchLineNumber AS NVARCHAR(10))  
             + ', "A", '  
                      + '"Y", '  
                      + '"Y" '  
             + 'FROM ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) '  
             + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQCDETAIL INVENTORYQCDETAIL (NOLOCK) '  
             + 'ON (INVENTORYQCDETAIL.QC_Key = INVENTORYQC.QC_Key AND INVENTORYQCDETAIL.Storerkey = INVENTORYQC.Storerkey) '  
                                     + 'JOIN ' + RTRIM(@c_SourceDBName) + '..SKU SKU (NOLOCK) '  
                                     + 'ON (INVENTORYQCDETAIL.Sku = SKU.Sku and INVENTORYQCDETAIL.Storerkey = SKU.Storerkey) '  
                                     + 'JOIN ' + RTRIM(@c_SourceDBName) + '..PACK PACK (NOLOCK) '  
                                     + 'ON (SKU.Packkey = PACK.Packkey) '  
             + 'WHERE INVENTORYQC.QC_Key = N''' + RTRIM(@c_QCkey) + ''' '  
             + 'AND INVENTORYQC.StorerKey = N''' + RTRIM(@c_astorerkey) + ''' '  
                                     + 'AND INVENTORYQCDETAIL.QCLineNo = N''' + RTRIM(@c_QClineno) + ''' '   
                                     + 'AND INVENTORYQCDETAIL.Status = "9" '   
                                     + 'GROUP BY '  
                           + 'INVENTORYQC.Reason, INVENTORYQC.Storerkey, INVENTORYQC.From_Facility, INVENTORYQC.To_Facility, '  
                                     + 'INVENTORYQCDETAIL.QCLineNo, INVENTORYQCDETAIL.Sku, INVENTORYQCDETAIL.Qty, ISNULL(PACK.PackUOM3,"EA"), '  
                                     + 'INVENTORYQCDETAIL.FromLoc, INVENTORYQCDETAIL.ToLoc, Convert(char(8),INVENTORYQC.AddDate,112) '  
  
                      IF @b_debug = 1   
                      BEGIN  
                         SELECT 'Type = IM ...'  
                         SELECT '@c_astorerkey', @c_astorerkey  
                   print @c_ExecStatements  
                      END  
  
                   EXEC sp_executesql @c_ExecStatements  
              END -- Type IM  
              ELSE  
              IF @c_reason = 'IT'  
               BEGIN  
                 IF ( @c_fromfacility = '1101' AND @c_tofacility = '1171' AND @c_tohostwhcode = 'SAMPLE') OR   
                    ( @c_fromfacility = '1101' AND @c_tofacility = '1171' AND @c_tohostwhcode = 'RETAIN') OR  
                    ( @c_fromfacility = '1106' AND @c_tofacility = '1101' ) OR   
                    ( @c_fromfacility = '1101' AND @c_tofacility = '1103' ) OR   
                    ( @c_fromfacility = '1103' AND @c_tofacility = '1101' ) OR   
                    ( @c_fromfacility = '1103' AND @c_tofacility = '1106' ) OR  
                    -- Added By Vicky on 10 Oct 2005  
                    ( @c_fromfacility = '1171' AND @c_tofacility = '1101' AND @c_fromhostwhcode = 'SAMPLE') OR  
                    -- Added By Vicky on 20-July-2006 (Start)  
                    ( @c_fromfacility = '1101' AND @c_tofacility = '1104' ) OR  
                    ( @c_fromfacility = '1104' AND @c_tofacility = '1101' ) OR  
                    ( @c_fromfacility = '1104' AND @c_tofacility = '1106' ) -- Added By Vicky on 20-July-2006 (End)  
                 BEGIN  
                  SELECT @c_ExecStatements = ''     
  
          SELECT @c_ExecStatements = N'INSERT INTO WYIQC (QC_Key, Reason, '  
                                         + 'Storerkey, From_Facility, To_Facility, QCLineNo, Sku, '  
                                         + 'Qty, UOM, FromLoc, ToLoc, FromHostWHCode, ToHostWHCode, IQCDate, '  
                                         + 'Batch, BatchLineNumber, Action, ProcessSource, ProcessDestination ) '  
                               + 'SELECT N''' + RTRIM(@c_QCkey) + ''', '  
                                         + 'INVENTORYQC.Reason, '  
                                         + 'INVENTORYQC.Storerkey, '  
                                         + 'INVENTORYQC.From_Facility, '  
                                         + 'INVENTORYQC.To_Facility, '  
                                         + 'INVENTORYQCDETAIL.QCLineNo, '  
                                         + 'INVENTORYQCDETAIL.Sku, '  
                                         + 'INVENTORYQCDETAIL.Qty, '  
                                         + 'ISNULL(PACK.PackUOM3,"EA"), '  
                                       + 'INVENTORYQCDETAIL.FromLoc, '  
                                       + 'INVENTORYQCDETAIL.ToLoc, '  
                                       + 'CASE WHEN INVENTORYQC.From_Facility = "1171" THEN (SELECT LOC.HOSTWHCODE FROM ' + RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) '  
                                       + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) ON (INVENTORYQC.From_Facility = LOC.Facility) '  
                                       + 'WHERE From_facility = N''' + RTRIM(@c_fromfacility) + ''' '  
                                       + 'AND LOC.Loc = N'''+RTRIM(@c_fromloc) + ''' AND INVENTORYQC.QC_Key = N''' +RTRIM(@c_QCKey) + ''' ) ELSE " " END,  '  
                                       + 'CASE WHEN INVENTORYQC.To_Facility = "1171" THEN (SELECT LOC.HOSTWHCODE FROM ' + RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) '  
                                       + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) ON (INVENTORYQC.To_Facility = LOC.Facility) '  
                                       + 'WHERE To_facility = N''' + RTRIM(@c_tofacility) + ''' '  
                                       + 'AND LOC.Loc = N'''+RTRIM(@c_toloc) + ''' AND INVENTORYQC.QC_Key = N''' +RTRIM(@c_QCKey) + ''' ) ELSE " " END,  '  
               + 'Convert(char(8),INVENTORYQC.AddDate,112), '  
               + 'N''' + @c_BatchNo + ''', '  
               + CAST(@n_DetBatchLineNumber AS NVARCHAR(10))  
               + ', "A", '  
                            + '"Y", '  
                            + '"Y" '  
               + 'FROM ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) '  
               + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQCDETAIL INVENTORYQCDETAIL (NOLOCK) '  
               + 'ON (INVENTORYQCDETAIL.QC_Key = INVENTORYQC.QC_Key AND INVENTORYQCDETAIL.Storerkey = INVENTORYQC.Storerkey) '  
                                         + 'JOIN ' + RTRIM(@c_SourceDBName) + '..SKU SKU (NOLOCK) '  
                                         + 'ON (INVENTORYQCDETAIL.Sku = SKU.Sku and INVENTORYQCDETAIL.Storerkey = SKU.Storerkey) '  
                                         + 'JOIN ' + RTRIM(@c_SourceDBName) + '..PACK PACK (NOLOCK) '  
                                         + 'ON (SKU.Packkey = PACK.Packkey) '  
               + 'WHERE INVENTORYQC.QC_Key = N''' + RTRIM(@c_QCkey) + ''' '  
               + 'AND INVENTORYQC.StorerKey = N''' + RTRIM(@c_astorerkey) + ''' '  
                                         + 'AND INVENTORYQCDETAIL.QCLineNo = N''' + RTRIM(@c_QClineno) + ''' '   
                                         + 'AND INVENTORYQCDETAIL.Status = "9" '   
                                         + 'GROUP BY '  
                                 + 'INVENTORYQC.Reason, INVENTORYQC.Storerkey, INVENTORYQC.From_Facility, INVENTORYQC.To_Facility, '  
                                         + 'INVENTORYQCDETAIL.QCLineNo, INVENTORYQCDETAIL.Sku, INVENTORYQCDETAIL.Qty, ISNULL(PACK.PackUOM3,"EA"), '  
                                         + 'INVENTORYQCDETAIL.FromLoc, INVENTORYQCDETAIL.ToLoc, Convert(char(8),INVENTORYQC.AddDate,112) '  
                     
                                IF @b_debug = 1   
                                BEGIN  
                                  SELECT '@c_astorerkey', @c_astorerkey  
                                  SELECT '@c_reason', @c_reason  
                                  SELECT '@c_fromfacility', @c_fromfacility  
                                  SELECT '@c_tofacility', @c_tofacility  
                                  SELECT '@c_toloc', @c_toloc  
                            print @c_ExecStatements  
                                END  
  
                              EXEC sp_executesql @c_ExecStatements  
                          END -- end facility checking  
                       END -- Type IT for storerkey 11312  
               END -- STorerkey = 11312  
               ELSE  
               IF @c_astorerkey = @c_StorerKey1 -- 11313  
               BEGIN  
                 IF @c_reason = 'IT'  
                 BEGIN  
                   IF ( @c_fromfacility = '1101' AND @c_tofacility = '1171' AND @c_tohostwhcode = 'SAMPLE') OR   
                      ( @c_fromfacility = '1101' AND @c_tofacility = '1171' AND @c_tohostwhcode = 'RETAIN') OR  
                      ( @c_fromfacility = '1171' AND @c_tofacility = '1101' AND @c_fromhostwhcode = 'SAMPLE') OR   
                      ( @c_fromfacility = '1171' AND @c_tofacility = '1101' AND @c_fromhostwhcode = 'RETAIN') OR  
                      ( @c_fromfacility = '1101' AND @c_tofacility = '1103' ) OR   
                      ( @c_fromfacility = '1103' AND @c_tofacility = '1101') OR   
                      ( @c_fromfacility = '1103' AND @c_tofacility = '1106' ) OR   
                      ( @c_fromfacility = '1103' AND @c_tofacility = '1171' AND @c_tohostwhcode = 'SAMPLE' ) OR   
                      ( @c_fromfacility = '1103' AND @c_tofacility = '1171' AND @c_tohostwhcode = 'RETAIN' ) OR   
                      ( @c_fromfacility = '1106' AND @c_tofacility = '1101') OR  
                      ( @c_fromfacility = '1101' AND @c_tofacility = '1106') OR   
                      -- Added By SHONG on 06-10-2005   
                      ( @c_fromfacility = '1171' AND @c_tofacility = '1103' AND @c_fromhostwhcode = 'RETAIN') OR  
                      -- Added By Vicky on 20-July-2006 (Start)  
                      ( @c_fromfacility = '1101' AND @c_tofacility = '1104') OR   
                      ( @c_fromfacility = '1104' AND @c_tofacility = '1101') OR   
                      ( @c_fromfacility = '1104' AND @c_tofacility = '1106') OR   
                      ( @c_fromfacility = '1171' AND @c_tofacility = '1104' AND @c_fromhostwhcode = 'RETAIN') -- Added By Vicky on 20-July-2006 (End)  
                    BEGIN  
                          
                        SELECT @c_ExecStatements = ''     
  
                SELECT @c_ExecStatements = N'INSERT INTO WYIQC (QC_Key, Reason, '  
                                           + 'Storerkey, From_Facility, To_Facility, QCLineNo, Sku, '  
                                           + 'Qty, UOM, FromLoc, ToLoc, FromHostWHCode, ToHostWHCode, IQCDate, '  
                                           + 'Batch, BatchLineNumber, Action, ProcessSource, ProcessDestination ) '  
                                       + 'SELECT N''' + RTRIM(@c_QCkey) + ''', '  
                                           + 'INVENTORYQC.Reason, '  
                                           + 'INVENTORYQC.Storerkey, '  
                                           + 'INVENTORYQC.From_Facility, '  
                                           + 'INVENTORYQC.To_Facility, '  
                                           + 'INVENTORYQCDETAIL.QCLineNo, '  
                                           + 'INVENTORYQCDETAIL.Sku, '  
                                           + 'INVENTORYQCDETAIL.Qty, '  
                                               + 'ISNULL(PACK.PackUOM3,"EA"), '  
                                           + 'INVENTORYQCDETAIL.FromLoc, '  
                                           + 'INVENTORYQCDETAIL.ToLoc, '  
                                           + 'CASE WHEN INVENTORYQC.From_Facility = "1171" THEN (SELECT LOC.HOSTWHCODE FROM ' + RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) '  
                                           + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) ON (INVENTORYQC.From_Facility = LOC.Facility) '  
                                           + 'WHERE From_facility = N''' + RTRIM(@c_fromfacility) + ''' '  
                                           + 'AND LOC.Loc = N'''+RTRIM(@c_fromloc) + ''' AND INVENTORYQC.QC_Key = N''' +RTRIM(@c_QCKey) + ''' ) ELSE " " END,  '  
                                           + 'CASE WHEN INVENTORYQC.To_Facility = "1171" THEN (SELECT LOC.HOSTWHCODE FROM ' + RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) '  
                                           + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) ON (INVENTORYQC.To_Facility = LOC.Facility) '  
                                           + 'WHERE To_facility = N''' + RTRIM(@c_tofacility) + ''' '  
                                           + 'AND LOC.Loc = N'''+RTRIM(@c_toloc) + ''' AND INVENTORYQC.QC_Key = N''' +RTRIM(@c_QCKey) + ''' ) ELSE " " END,  '  
                 + 'Convert(char(8),INVENTORYQC.AddDate,112), '  
                 + 'N''' + @c_BatchNo + ''', '  
                 + CAST(@n_DetBatchLineNumber AS NVARCHAR(10))  
                 + ', "A", '  
                            + '"Y", '  
                            + '"Y" '  
                 + 'FROM ' + RTRIM(@c_SourceDBName) + '..INVENTORYQC INVENTORYQC (NOLOCK) '  
                 + 'JOIN ' + RTRIM(@c_SourceDBName) + '..INVENTORYQCDETAIL INVENTORYQCDETAIL (NOLOCK) '  
                 + 'ON (INVENTORYQCDETAIL.QC_Key = INVENTORYQC.QC_Key AND INVENTORYQCDETAIL.Storerkey = INVENTORYQC.Storerkey) '  
                                           + 'JOIN ' + RTRIM(@c_SourceDBName) + '..SKU SKU (NOLOCK) '  
                                           + 'ON (INVENTORYQCDETAIL.Sku = SKU.Sku and INVENTORYQCDETAIL.Storerkey = SKU.Storerkey) '  
                                           + 'JOIN ' + RTRIM(@c_SourceDBName) + '..PACK PACK (NOLOCK) '  
                                           + 'ON (SKU.Packkey = PACK.Packkey) '  
                 + 'WHERE INVENTORYQC.QC_Key = N''' + RTRIM(@c_QCkey) + ''' '  
                 + 'AND INVENTORYQC.StorerKey = N''' + RTRIM(@c_astorerkey) + ''' '  
                                           + 'AND INVENTORYQCDETAIL.QCLineNo = N''' + RTRIM(@c_QClineno) + ''' '   
                                           + 'AND INVENTORYQCDETAIL.Status = "9" '   
                                           + 'GROUP BY '  
                                       + 'INVENTORYQC.Reason, INVENTORYQC.Storerkey, INVENTORYQC.From_Facility, INVENTORYQC.To_Facility, '  
                                           + 'INVENTORYQCDETAIL.QCLineNo, INVENTORYQCDETAIL.Sku, INVENTORYQCDETAIL.Qty, ISNULL(PACK.PackUOM3,"EA"), '  
                                           + 'INVENTORYQCDETAIL.FromLoc, INVENTORYQCDETAIL.ToLoc, Convert(char(8),INVENTORYQC.AddDate,112) '  
                     
                                IF @b_debug = 1   
                                BEGIN  
                                  SELECT '@c_astorerkey', @c_astorerkey  
                                  SELECT '@c_reason', @c_reason  
                                  SELECT '@c_fromfacility', @c_fromfacility  
                                  SELECT '@c_tofacility', @c_tofacility  
                                  SELECT '@c_toloc', @c_toloc  
                                  SELECT '@c_fromloc', @c_fromloc   
                                  SELECT '@c_fromhostwhcode', @c_fromhostwhcode   
                            print @c_ExecStatements  
                                END  
  
                              EXEC sp_executesql @c_ExecStatements  
                     END -- facility  
               END -- Type IT  
            END -- Storerkey 11313    
  
        IF @@ERROR = 0  
        BEGIN   
         IF @b_debug = 1  
         BEGIN  
            SELECT 'Insert Into WYIQC table is Done !'  
         END  
   
           COMMIT TRAN  
        END  
        ELSE  
        BEGIN  
           ROLLBACK TRAN  
           SELECT @n_continue = 3  
         SELECT @n_err = 65002  
             SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert records failed (isp_Wyeth_IQC_Export)'    
        END  
  
      BEGIN TRAN  
      UPDATE WYIQC  
       SET DetailRow = @n_DetCounter  
     WHERE Rowid = RTRIM(@n_RowId)  
  
        IF @@ERROR = 0  
          BEGIN   
        IF @b_debug = 1  
        BEGIN  
           SELECT 'Update to WYIQC table is Done !'  
        END  
  
            COMMIT TRAN  
           END  
          ELSE  
          BEGIN  
            ROLLBACK TRAN  
            SELECT @n_continue = 3  
          SELECT @n_err = 65003  
              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update record failed (isp_Wyeth_IQC_Export)'    
          END  
           END -- Not Exists  
       END -- While 1=1   
  
  
        IF @b_debug = 1   
        BEGIN  
           SELECT * FROM ##TempWyIQC (NOLOCK)  
        END  
  
       -- Drop Temp Table  
        DROP TABLE ##TempWyIQC   
  
        SELECT @c_ExecStatements = ''  
        SELECT @c_ExecStatements = N'UPDATE ' + RTRIM(@c_SourceDBName) + '..TransmitLog3 '  
                                + 'SET Transmitflag = "3" '  
                                + 'WHERE Key1 not in (SELECT DISTINCT QC_Key FROM WYIQC (NOLOCK)) '  
                                + 'AND Transmitflag = "1" AND Tablename = "IQCLOG" '     
                                + 'AND Key3 in ( N''' + RTRIM(@c_StorerKey) + '''' + ' , N''' + RTRIM(@c_StorerKey1) + '''' + ')'  
  
        IF @b_debug = 1   
        BEGIN  
           Print @c_ExecStatements  
        END  
  
        EXEC sp_executesql @c_ExecStatements   
       -- Insert Record to Transaction Summary  
       /* Declare @c_trandate NVARCHAR(8)  
            
        SELECT @c_trandate = Convert(char(8), getdate(), 112)            
  
        SELECT @n_cnthdtrans = count(*)   
        FROM WYIQC (NOLOCK)  
  
        INSERT INTO WYTRX (Transactiondate, InterfaceType, TotalHeaderRec, TotalDetailRec, Batch, BatchLineNumber, Action, ProcessSource, ProcessDestination)  
        VALUES(@c_trandate, 'IQC', @n_cnthdtrans, '', @c_BatchNo, 1, 'A', 'Y', 'Y')  
       -- END   
        
        IF @b_debug = 1  
  BEGIN  
         SELECT 'Update to WYTRX table is Done !'  
                SELECT * FROM WYTRX (NOLOCK) WHERE InterfaceType = 'IQC'  
  END */  
  
   /* #INCLUDE <SPTPA01_2.SQL> */    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
 ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
   BEGIN    
          COMMIT TRAN    
         END    
      END    
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Wyeth_IQC_Export'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
 END    
END

GO