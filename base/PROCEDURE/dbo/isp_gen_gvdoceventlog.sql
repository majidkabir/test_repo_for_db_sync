SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Gen_GVDocEventLog                              */
/* Creation Date: 11-Feb-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 16-03-2018   tlting    remove Event_LOC value                        */  
/* 20-03-2018   tlting    DocumnetNo show RD.externreceiptkey           */ 
/*                        (poexternkey)                                 */ 
/************************************************************************/
CREATE PROC [dbo].[isp_Gen_GVDocEventLog]    
AS      
BEGIN  
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
       
   DECLARE @c_DocumentNo NVARCHAR(10)    
   DECLARE @n_RowRef BIGINT  
   DECLARE @n_CutOffDate DATETIME  
   DECLARE @n_FirstRecord BIGINT  
  
   DECLARE @c_country NVARCHAR(10)  
    
   Declare @nDebug   int    
   Set @nDebug = 0    
   
   SET @n_CutOffDate = GETDATE()  
   SET @n_FirstRecord = 0  
  
   BEGIN TRAN  
  
   SET @c_country = ''  
     
   SELECT  @c_country = NSQLValue  
   FROM dbo.NSQLCONFIG  
   WHERE ConfigKey = 'CountryISO'  
  
   CREATE TABLE #TDocNo (RowRef Bigint)  
   
   IF EXISTS ( SELECT 1   
               FROM dbo.DocStatusTrack DST (NOLOCK)   
               JOIN Codelkup C (NOLOCK) ON C.Listname = N'GVTITF' AND C.Code = DST.TableName  
                                AND C.Code2 = DST.DocStatus AND C.Storerkey = DST.Storerkey  
               WHERE DST.TableName = N'ASNSTS'  
               AND DST.Finalized  = 'N'  )  
   BEGIN   
      INSERT INTO #TDocNo (RowRef)  
      SELECT  DST.RowRef    
      FROM dbo.DocStatusTrack DST (NOLOCK)   
      JOIN Codelkup C (NOLOCK) ON C.Listname = N'GVTITF' AND C.Code = DST.TableName  
                       AND C.Code2 = DST.DocStatus AND C.Storerkey = DST.Storerkey  
      WHERE DST.TableName = N'ASNSTS'  
      AND DST.Finalized  = 'N'  
      ORDER BY DST.RowRef   
          
    DECLARE Orders_Load_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
     SELECT  RowRef    
      FROM #TDocNo  
      ORDER BY RowRef   
  
    OPEN Orders_Load_Cur   
    FETCH NEXT FROM Orders_Load_Cur INTO @n_RowRef  
    WHILE @@FETCH_STATUS = 0   
    BEGIN   
  
     Update DocStatusTrack with (RowLock)   
     Set Finalized = 'Y' , EditDate = @n_CutOffDate  
     Where RowRef = @n_RowRef  
       
     FETCH NEXT FROM Orders_Load_Cur INTO @n_RowRef   
    END  
    CLOSE Orders_Load_Cur   
    DEALLOCATE Orders_Load_Cur  
   END  
  
   DECLARE @c_Key1           nvarchar(20)  
         , @c_DocStatus      nvarchar(10)  
         , @c_TransDate      DATETIME  
         , @c_Userdefine01   nvarchar(30)  
         , @c_StorerKey      nvarchar(15)  
         , @c_Long           NVARCHAR(250)  
         , @c_TableName      NVARCHAR(30)  
         , @c_ExternPOKey    NVARCHAR(20)  
         , @c_POkey          NVARCHAR(10)   
         , @c_Facility       NVARCHAR(10)  


              
   DECLARE CUR_DocStatusTrack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                              
   SELECT DST.DocumentNo, DST.TransDate, DST.Storerkey, DST.DocStatus,   
   DST.Userdefine01, C.Long, DST.TableName, RTRIM(RD.externreceiptkey)
   FROM dbo.DocStatusTrack DST (NOLOCK)   
   JOIN Codelkup C (NOLOCK) ON C.Listname = N'GVTITF' AND C.Code = DST.TableName  
                    AND C.Code2 = DST.DocStatus AND C.Storerkey = DST.Storerkey  
   LEFT	JOIN REceiptdetail RD (NOLOCK) ON RD.ReceiptKey = DST.DocumentNo
   JOIN #TDocNo ON #TDocNo.rowref = DST.RowRef                   
   GROUP BY DST.DocumentNo, DST.TransDate, DST.Storerkey, DST.DocStatus,   
   DST.Userdefine01, C.Long, DST.TableName, RD.externreceiptkey
   Order by  DST.DocumentNo, RD.externreceiptkey
     
     
   OPEN CUR_DocStatusTrack  
     
   FETCH NEXT FROM CUR_DocStatusTrack INTO @c_DocumentNo, @c_TransDate, @c_StorerKey, @c_DocStatus,     
                             @c_Userdefine01, @c_Long, @c_TableName, @c_ExternPOKey  
     
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @c_TableName = N'ASNSTS'  
      BEGIN    
       --SET @c_Facility = ''  
         
       --SELECT @c_Facility = c.Long   
       --FROM RECEIPT AS r WITH(NOLOCK)  
       --JOIN CODELKUP AS c WITH(NOLOCK) ON c.LISTNAME = 'LOGIFAC' AND c.Short=r.Facility  
       --WHERE r.ReceiptKey = @c_DocumentNo         
         
       --IF @c_Facility <> ''  
       --   SET @c_Key1 = @c_Facility  
          
      IF @c_ExternPOKey <> ''
		 BEGIN  
           SET @c_DocumentNo = @c_ExternPOKey   
         END  
      END  


      -- TLTING01 remove this.
	--IF EXISTS ( SELECT 1 from GVDocEventLog (NOLOCK) WHERE DocumentNo = @c_DocumentNo AND  EVent_Code = @c_Long )
	--BEGIN
	--	GOTO NextLINE
	--END  
	   
	  INSERT INTO GVDocEventLog (DocumentNo, Transdate, Storerkey, DocStatus, Event_LOC, Event_Country, Source_Order,   
							Event_Code)  
      VALUES( @c_DocumentNo, @c_TransDate, @c_StorerKey, @c_DocStatus, '' ,@c_country, @c_Userdefine01, @c_Long )  
      
	  NextLINE:
	     
      FETCH NEXT FROM CUR_DocStatusTrack INTO @c_DocumentNo, @c_TransDate, @c_StorerKey, @c_DocStatus,     
                          @c_Userdefine01, @c_Long, @c_TableName  , @c_ExternPOKey
   END   
   CLOSE CUR_DocStatusTrack  
   DEALLOCATE CUR_DocStatusTrack  
    
   COMMIT TRAN  
END  

GO