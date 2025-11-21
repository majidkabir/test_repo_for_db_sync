SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************************/            
/* Stored Proc : isp_ArchiveMbol                                                                   */            
/* Creation Date:                                                                                  */            
/* Copyright: IDS                                                                                  */            
/* Written by:                                                                                     */            
/*                                                                                                 */            
/* Purpose:                                                                                        */            
/*                                                                                                 */            
/* Called By: nspArchiveShippingOrder                                                              */            
/*                                                                                                 */          
/* Data Modifications:                                                                             */            
/*                                                                                                 */            
/* Updates:                                                                                        */            
/* Date         Author        Purposes                                                             */            
/* 2005-Aug-09  Shong         Performance Tuning                                                   */            
/* 2005-Aug-10  Ong           SOS38267 : obselete sku & storerkey                                  */            
/* 2005-Nov-28  Shong         Change Commit transaction strategy to row Level to Reduce Blocking.  */           
/* 2005-Nov-30  Shong         SOS40882 - Archive MBOL only when all the Orders in the MBOLDetail   */           
/*                            was Archived                                                         */            
/*                            SOS40064 - Archive Those MBOL which Orders No Longer Exists.         */            
/* 13-APR-2006  June          Include Manual Order                                                 */            
/* 24-Apr-2012  Leong         SOS# 242479 - Update MBOL.ArchiveCop with TrafficCop                 */            
/* 10-Mar-2023  kelvinongcy    WMS-21896 Delay Mbol Archive by storerconfig (kocy01)               */          
/* 28-Jun-2023  TLTING01      Revise condition filtering                                           */          
/***************************************************************************************************/            
          
CREATE   PROC [dbo].[isp_ArchiveMbol]            
   @c_copyfrom_db             NVARCHAR(55),            
   @c_copyto_db               NVARCHAR(55),            
   @copyrowstoarchivedatabase NVARCHAR(1),           
   @n_retain_days             int,          
   @b_success                 int OUTPUT            
AS            
/*--------------------------------------------------------------*/            
-- THIS ARCHIVE SCRIPT IS EXECUTED FROM nsparchiveshippingorder            
/*--------------------------------------------------------------*/            
BEGIN -- main            
            
   /* BEGIN 2005-Aug-10 (SOS38267) */            
   SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   /* END 2005-Aug-10 (SOS38267) */            
            
   DECLARE @n_continue int,            
           @n_starttcnt int, -- holds the current transaction count            
           @n_cnt int,       -- holds @@rowcount after certain operations            
           @b_debug int      -- debug on or off            
            
   /* #include <sparpo1.sql> */            
   DECLARE @n_archive_mbol_records   int, -- # of MBOL records to be archived            
           @n_archive_mbol_Detail_records int, -- # of MBOLDetail records to be archived            
           @n_err                         int,            
           @c_errmsg                      NVARCHAR(254),            
           @local_n_err                   int,            
           @local_c_errmsg                NVARCHAR(254),            
           @c_temp     NVARCHAR(254)            
            
   DECLARE @cMBOLKey  NVARCHAR(10),            
           @cMBOLLine NVARCHAR(5)          
                 
            
   DECLARE @c_StorerKey nvarchar(15) = '',               --kocy01        
            @c_PrevStorerKey NVARCHAR (15) = '',                 
            @n_DelayArchiveMBOL_Exist int = 0 ,           
            @c_DelayArchiceMBOL_retaindays int = 0          
            
   SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',            
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '            
            
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      IF (@b_debug =1 )            
      BEGIN            
         PRINT 'starting table existence check for MBOL...'            
      END            
      SELECT @b_success = 1            
      EXEC nsp_build_archive_table            
            @c_copyfrom_db,            
            @c_copyto_db,            
            'MBOL',            
            @b_success OUTPUT,            
            @n_err     OUTPUT,            
            @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
            
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      IF (@b_debug =1 )            
      BEGIN            
         PRINT 'starting table existence check for MBOLDetail...'            
      END            
      SELECT @b_success = 1            
      EXEC nsp_build_archive_table            
            @c_copyfrom_db,            
            @c_copyto_db,            
            'MBOLDetail',            
            @b_success OUTPUT,            
            @n_err     OUTPUT,            
            @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
            
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      IF (@b_debug =1 )            
      BEGIN            
         PRINT 'building alter table string for MBOL...'            
      END            
      EXECUTE nspbuildaltertablestring            
            @c_copyto_db,            
            'MBOL',            
            @b_success OUTPUT,            
            @n_err     OUTPUT,            
            @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
            
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      IF (@b_debug =1 )            
      BEGIN            
         PRINT 'building alter table string for MBOLDetail...'            
      END            
      EXECUTE nspbuildaltertablestring            
              @c_copyto_db,            
              'MBOLDetail',            
              @b_success OUTPUT,            
              @n_err     OUTPUT,            
              @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
          
   IF OBJECT_ID(N'tempdb..#MBOL') IS NOT NULL DROP TABLE #MBOL        --kocy01        
   CREATE TABLE #MBOL (  
      RowRef INT IDENTITY (1,1) NOT NULL,   
      MbolKey NVARCHAR (15) NULL CONSTRAINT DF_#MBOL_Mbolkey DEFAULT ('') ,   
      StorerKey NVARCHAR (15) NULL CONSTRAINT DF_#MBOL_Storerkey DEFAULT ('') )          
            
   WHILE @@trancount > 0            
      COMMIT TRAN            
            
      SELECT @n_archive_MBOL_records = 0            
      SELECT @n_archive_MBOL_Detail_records = 0            
            
         INSERT #MBOL (MbolKey,StorerKey)      --kocy01        
         SELECT MBOLKEY , StorerKey           
         FROM  ORDERDETAIL WITH (NOLOCK)           
         GROUP BY MBOLKEY, StorerKey          
         HAVING COUNT(DISTINCT ISNULL(OrderDetail.ArchiveCop, '')) = 1            
         AND MAX(ISNULL(OrderDetail.ArchiveCop, '')) = '9'           
          
         -- UNION ALL          
         INSERT #MBOL (MbolKey,StorerKey)       --kocy01        
         SELECT MBOL.MBOLKEY , ArvO.StorerKey          
         FROM MBOL WITH (NOLOCK)            
          JOIN MBOLDetail MD WITH (NOLOCK) ON MD.MBOLKey = MBOL.MBOLKEY      
          JOIN [ARCHIVE].[orders] ArvO WITH (NOLOCK) ON ArvO.Orderkey = MD.Orderkey    
         WHERE MBOL.Status = '9'            
         AND NOT EXISTS ( SELECT 1 from Orders O (NOLOCK) WHERE O.Orderkey = MD.Orderkey )  
          
         -- UNION ALL          
         INSERT #MBOL (MbolKey,StorerKey)         --kocy01        
         SELECT MBOLKEY , StorerKey          
         FROM  ORDERS WITH (NOLOCK)            
         -- WHERE ORDERS.UserDefine08 = '2'     June 13-Apr-2006            
         WHERE (ORDERS.UserDefine08 = '2' OR TYPE = 'M')            
         AND MBOLKEY > ''            
         GROUP BY MBOLKEY, StorerKey          
         HAVING COUNT(DISTINCT ISNULL(ORDERS.ArchiveCop, '')) = 1            
         AND MAX(ISNULL(ORDERS.ArchiveCop, '')) = '9'           
         ORDER BY MBOLKey            
          
      DECLARE C_ARC_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
      SELECT DISTINCT MbolKey, StorerKey FROM #MBOL     
      WHERE StorerKey <> '' AND StorerKey is NOT NULL  
      ORDER BY StorerKey, MbolKey  --tlting01  
        
      OPEN C_ARC_MBOL            
      FETCH NEXT FROM C_ARC_MBOL INTO @cMBOLKey , @c_StorerKey          
            
      WHILE @@fetch_status <> -1 AND (@n_continue = 1 or @n_continue = 2)            
      BEGIN            
         BEGIN TRAN            
                    
            --kocy01 (S)        
            IF @c_StorerKey <> @c_PrevStorerKey              
            BEGIN                
               SET @c_PrevStorerKey = @c_StorerKey               
               SELECT @n_DelayArchiveMBOL_Exist = 0              
               SELECT @b_success = 1           
                         
               EXECUTE nspGetRight                 
                  NULL,          -- facility                
                  @c_StorerKey, -- StorerKey                
                  NULL,          -- Sku                
                  'DelayArchiveMBOL', -- Configkey for MBOL delay archive               
                  @b_Success OUTPUT,               
                  @n_DelayArchiveMBOL_Exist OUTPUT,     -- this is return result              
                  @n_err OUTPUT,                
                  @c_errmsg OUTPUT,          
                  @c_DelayArchiceMBOL_retaindays OUTPUT          
                          
               IF (@n_err <> 0)              
               BEGIN              
                  SELECT @n_continue = 3              
                  SELECT @c_errmsg = N' FAIL Retrieved.  ConfigKey ''DelayArchiveMBOL'' for storerkey ''' +@c_StorerKey              
                                    +'''.  Refer StorerConfig Table'              
               END                 
               IF (@b_debug=1)              
               BEGIN              
                  PRINT 'Storerkey = ' + @c_StorerKey + ' , DelayArchiveMBOL_Exist = ' + Cast(@n_DelayArchiveMBOL_Exist as nvarchar)              
               END              
            END--END @c_StorerKey <> @c_PrevStorerKey               
          
            IF @n_DelayArchiveMBOL_Exist = 0          
            BEGIN      
               IF @n_continue = 1 or @n_continue = 2            
               BEGIN          -- TLTING01            
                  UPDATE MBOL WITH (ROWLOCK)            
                  SET MBOL.ArchiveCop = '9'            
                    , MBOL.TrafficCop = NULL -- SOS# 242479            
                  WHERE MBOL.MBOLkey = @cMBOLKey            
            
                  SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
                  SELECT @n_archive_MBOL_records = @n_archive_MBOL_records + 1            
            
                  IF @local_n_err <> 0            
                  BEGIN            
                     SELECT @n_continue = 3            
                     SELECT @local_n_err = 77303            
                     SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)            
                     SELECT @local_c_errmsg = ': UPDATE of ArchiveCop failed - MBOLDetail. (isp_ArchiveMBOL) ' + ' ( ' +            
                                              ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'            
                     ROLLBACK TRAN            
                  END            
                  ELSE            
                  BEGIN            
                     COMMIT TRAN            
                  END            
               END   --tlting01 END  
  
               IF @n_continue = 1 or @n_continue = 2            
               BEGIN            
          
                  DECLARE C_ARC_MBOLDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
                  SELECT MBOLLineNumber          --TLTING01  
                  FROM   MBOLDetail WITH (NOLOCK)          
                  JOIN  MBOL WITH (NOLOCK) ON MBOLDETAIL.MbolKey = MBOL.MboLKey          
                  WHERE MBOL.MBOLKey = @cMBOLKey            
                     AND  MBOL.ArchiveCop = '9'  
        
            
                  OPEN C_ARC_MBOLDetail            
                  FETCH NEXT FROM C_ARC_MBOLDetail INTO @cMBOLLine            
            
                  WHILE @@fetch_status <> -1 AND (@n_continue = 1 or @n_continue = 2)            
                  BEGIN            
                     BEGIN TRAN            
            
                     UPDATE MBOLDetail WITH (ROWLOCK)            
                     SET MBOLDetail.ArchiveCop = '9'            
                       , MBOLDetail.TrafficCop = NULL -- SOS# 242479            
                     WHERE MBOLkey = @cMBOLKey AND MBOLLineNumber = @cMBOLLine            
            
                     SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
                     SELECT @n_archive_MBOL_Detail_records = @n_archive_MBOL_Detail_records + 1            
            
                     IF @local_n_err <> 0            
                     BEGIN            
                        SELECT @n_continue = 3            
                        SELECT @local_n_err = 77303            
                        SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)            
                        SELECT @local_c_errmsg = ': UPDATE of ArchiveCop failed - MBOLDetail. (isp_ArchiveMBOL) ' + ' ( ' +            
                                                 ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'            
                        ROLLBACK TRAN            
                     END            
                     ELSE            
                     BEGIN            
                        COMMIT TRAN            
                     END            
            
                     FETCH NEXT FROM C_ARC_MBOLDetail INTO @cMBOLLine            
                  END            
                  CLOSE C_ARC_MBOLDetail            
                  DEALLOCATE C_ARC_MBOLDetail            
               END          
             END  --IF @n_DelayArchiveMBOL_Exist = 0          
               
             IF @n_DelayArchiveMBOL_Exist = 1          
             BEGIN              
               IF @c_DelayArchiceMBOL_retaindays IS NULL OR @c_DelayArchiceMBOL_retaindays = ''  
               BEGIN  
                    SET @c_DelayArchiceMBOL_retaindays = '0'  
               END  
               
               IF @n_retain_days > @c_DelayArchiceMBOL_retaindays          
               BEGIN          
                  --SELECT @n_continue = 3            
                  --SET @local_c_errmsg = 'Orders Archive days retain cannot longer than Mbol Archive.'+ char(13) +          
                  --                      'Refer StorerConfig Table. ConfigKey - DelayArchiveMBOL '           
                  IF (@b_debug =1 )            
                  BEGIN            
                     PRINT 'Orders archive days retention :' + cast(@n_retain_days as nvarchar)   
                     PRINT 'MBOL archive days retention :' + cast (@c_DelayArchiceMBOL_retaindays as nvarchar)          
                  END                   
               END          
  
               IF @n_continue = 1 or @n_continue = 2            
               BEGIN      -- TLTING01                                    
                  UPDATE MBOL WITH (ROWLOCK)            
                  SET MBOL.ArchiveCop = '9'            
                    , MBOL.TrafficCop = NULL           
                   FROM MBOL           
                   --LEFT JOIN ORDERS (NOLOCK) ON ORDERS.MBOLKEy = MBOL.MBOLKEY    --tlting01      
                   WHERE MBOL.MBOLkey = @cMBOLKey           
                   -- AND ORDERS.Storerkey = @c_StorerKey         --TLTING01  
                   AND  MBOL.EditDate  < Dateadd (day, 0 - @c_DelayArchiceMBOL_retaindays, convert(char(11), getdate(), 112))  
                    
                   SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
                   SELECT @n_archive_MBOL_records = @n_archive_MBOL_records + 1           
                         
                  IF @local_n_err <> 0            
                  BEGIN            
                     SELECT @n_continue = 3            
                     SELECT @local_n_err = 77303            
                     SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)            
                     SELECT @local_c_errmsg = ': UPDATE of ArchiveCop failed - MBOLDetail. (isp_ArchiveMBOL) ' + ' ( ' +            
                                              ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'            
                     ROLLBACK TRAN            
                  END            
                  ELSE            
                  BEGIN            
                     COMMIT TRAN            
                  END            
               END -- TLTING01 END  
                 
               IF @n_continue = 1 or @n_continue = 2            
               BEGIN            
                  DECLARE C_ARC_MBOLDetail_DELAY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                     SELECT MBOLLineNumber          --TLTING01  
                     FROM   MBOLDetail WITH (NOLOCK)          
                      JOIN  MBOL WITH (NOLOCK) ON MBOLDETAIL.MbolKey = MBOL.MboLKey          
                     WHERE MBOL.MBOLKey = @cMBOLKey            
                      AND  MBOL.ArchiveCop = '9'  
  
                     --SELECT MBOLLineNumber            
                     --FROM   MBOLDetail WITH (NOLOCK)          
                     --LEFT JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.MbolKey = ORDERS.MboLKey          
                     --WHERE MBOLDETAIL.MBOLKey = @cMBOLKey            
                     --AND ORDERS.Storerkey = @c_StorerKey          
                     --AND DATEDIFF (day, MBOLDetail.EditDate, getdate() ) > @c_DelayArchiceMBOL_retaindays          
            
                  OPEN C_ARC_MBOLDetail_DELAY            
                  FETCH NEXT FROM C_ARC_MBOLDetail_DELAY INTO @cMBOLLine            
            
                  WHILE @@fetch_status <> -1 AND (@n_continue = 1 or @n_continue = 2)            
                  BEGIN            
                     BEGIN TRAN            
            
                     UPDATE MBOLDetail WITH (ROWLOCK)            
                     SET MBOLDetail.ArchiveCop = '9'            
                       , MBOLDetail.TrafficCop = NULL -- SOS# 242479            
                     WHERE MBOLkey = @cMBOLKey AND MBOLLineNumber = @cMBOLLine            
            
                     SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
                     SELECT @n_archive_MBOL_Detail_records = @n_archive_MBOL_Detail_records + 1            
            
                     IF @local_n_err <> 0            
                     BEGIN            
                        SELECT @n_continue = 3            
                        SELECT @local_n_err = 77303            
                        SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)            
                        SELECT @local_c_errmsg = ': UPDATE of ArchiveCop failed - MBOLDetail. (isp_ArchiveMBOL) ' + ' ( ' +            
                                                 ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'            
                        ROLLBACK TRAN            
                     END            
                     ELSE            
                     BEGIN            
                        COMMIT TRAN            
                     END            
            
                     FETCH NEXT FROM C_ARC_MBOLDetail_DELAY INTO @cMBOLLine            
                  END            
                  CLOSE C_ARC_MBOLDetail_DELAY            
                  DEALLOCATE C_ARC_MBOLDetail_DELAY            
               END            
             END --IF @n_DelayArchiveMBOL_Exist = 1         
            --kocy01 (E)        
            
         FETCH NEXT FROM C_ARC_MBOL INTO @cMBOLKey , @c_Storerkey           
      END            
      CLOSE C_ARC_MBOL            
      DEALLOCATE C_ARC_MBOL            
            
   IF ((@n_continue = 1 or @n_continue = 2)  AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      SELECT @c_temp = 'attempting to archive ' + RTRIM(CONVERT(NVARCHAR(6),@n_archive_mbol_records )) +            
                       ' MBOL records AND ' + RTRIM(CONVERT(NVARCHAR(6),@n_archive_mbol_Detail_records )) + ' MBOLDetail records'            
      EXECUTE nsplogalert            
               @c_modulename   = 'isp_ArchiveMbol',            
               @c_alertmessage = @c_temp ,            
               @n_severity     = 0,            
               @b_success      = @b_success OUTPUT,            
               @n_err          = @n_err     OUTPUT,            
               @c_errmsg       = @c_errmsg  OUTPUT            
 IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
            
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      IF (@b_debug =1 )            
      BEGIN            
         PRINT 'building insert for MBOLDetail...'            
      END            
      SELECT @b_success = 1            
      EXEC nsp_build_insert            
            @c_copyto_db,            
            'MBOLDetail',            
            1,            
            @b_success OUTPUT,            
            @n_err     OUTPUT,            
            @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
            
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')            
   BEGIN            
      IF (@b_debug =1 )            
      BEGIN            
         PRINT 'building insert for MBOL...'            
      END            
      SELECT @b_success = 1            
      EXEC nsp_build_insert            
          @c_copyto_db,            
            'MBOL',            
            1,            
            @b_success OUTPUT,            
            @n_err     OUTPUT,            
            @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
            
   WHILE @@trancount > 0            
      COMMIT TRAN            
            
   IF @n_continue = 1 or @n_continue = 2            
   BEGIN            
      SELECT @b_success = 1            
      EXECUTE nsplogalert            
               @c_modulename   = 'isp_ArchiveMbol',            
               @c_alertmessage = 'archive of MBOL ended successfully.',            
               @n_severity     = 0,            
               @b_success      = @b_success OUTPUT,            
               @n_err          = @n_err     OUTPUT,            
               @c_errmsg       = @c_errmsg  OUTPUT            
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
   ELSE            
   BEGIN            
      IF @n_continue = 3            
      BEGIN            
         SELECT @b_success = 1            
         EXECUTE nsplogalert            
                  @c_modulename   = 'isp_ArchiveMbol',            
                  @c_alertmessage = 'archive of MBOL failed - check this log for additional messages.',            
                  @n_severity     = 0,            
                  @b_success      = @b_success OUTPUT,            
                  @n_err          = @n_err     OUTPUT,            
                  @c_errmsg       = @c_errmsg  OUTPUT           
                           
         IF NOT @b_success = 1            
         BEGIN            
            SELECT @n_continue = 3            
         END            
      END            
   END            
          
     /* #include <sparpo2.sql> */            
   IF @n_continue=3  -- error occured - process AND return            
   BEGIN            
      SELECT @b_success = 0            
      IF @@trancount > 0            
      BEGIN            
         ROLLBACK TRAN         
      END            
      ELSE            
      BEGIN            
         while @@trancount > 0            
         BEGIN            
            COMMIT TRAN            
         END            
      END            
            
      SELECT @n_err = @local_n_err            
      SELECT @c_errmsg = @local_c_errmsg            
      IF (@b_debug = 1)            
      BEGIN            
         SELECT @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'            
      END            
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ArchiveMbol'            
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012            
      RETURN            
   END            
   ELSE            
   BEGIN            
      SELECT @b_success = 1            
      while @@trancount > 0            
      BEGIN            
         COMMIT TRAN            
      END            
      RETURN            
   END            
END -- main 

GO