SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_EXG_FilterCondition6                            */  
/* Creation Date: 10-Mar-2021                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GuanHao Chan                                              */  
/*                                                                       */  
/* Purpose: Excel Generator Sub StoredProcedure FilterConfition 6.       */  
/*                                                                       */  
/* Called By:  ExcelGenerator                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 10-Mar-2021   GHChan   1.0  Initial Development                       */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_EXG_FilterCondition6]  
(  @c_Username    NVARCHAR(200)  = ''  
,  @n_EXG_Hdr_ID  INT            = 0  
,  @c_FileNameFormat NVARCHAR(200)  = ''  
,  @c_ParamVal1   NVARCHAR(200)  = ''  
,  @c_ParamVal2   NVARCHAR(200)  = ''  
,  @c_ParamVal3   NVARCHAR(200)  = ''  
,  @c_ParamVal4   NVARCHAR(200)  = ''  
,  @c_ParamVal5   NVARCHAR(200)  = ''  
,  @c_ParamVal6   NVARCHAR(200)  = ''  
,  @c_ParamVal7   NVARCHAR(200)  = ''  
,  @c_ParamVal8   NVARCHAR(200)  = ''  
,  @c_ParamVal9   NVARCHAR(200)  = ''  
,  @c_ParamVal10  NVARCHAR(200)  = ''  
,  @c_FileKeyList NVARCHAR(500)  = ''  OUTPUT  
,  @b_Debug       INT            = 1  
,  @b_Success     INT            = 1   OUTPUT  
,  @n_Err         INT            = 0   OUTPUT  
,  @c_ErrMsg      NVARCHAR(250)  = ''  OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
  
   DECLARE @n_Continue     INT           = 1  
         , @n_StartTcnt    INT           = @@TRANCOUNT  
         , @n_ITFErr       INT           = 0  
         , @c_ITFErrMsg    NVARCHAR(250) = ''  
         , @c_FileExt      NVARCHAR(10)  = ''  
  
         , @n_FileKey      INT           = 0  
         , @c_TargetFolder NVARCHAR(500) = ''  
         , @c_FileName     NVARCHAR(255) = ''  
         , @c_Delimiter    NVARCHAR(2)   = ','  
         , @b_RetryFlag    BIT           = 0  
  
         , @c_ValidPVal1   NVARCHAR(200) = ''  
         , @c_ValidPVal2   NVARCHAR(200) = ''  
         , @c_ValidPVal3   NVARCHAR(200) = ''  
         , @c_ValidPVal4   NVARCHAR(200) = ''  
         , @c_ValidPVal5   NVARCHAR(200) = ''  
         , @c_ValidPVal6   NVARCHAR(200) = ''  
         , @c_ValidPVal7   NVARCHAR(200) = ''  
         , @c_ValidPVal8   NVARCHAR(200) = ''  
         , @c_ValidPVal9   NVARCHAR(200) = ''  
         , @c_ValidPVal10  NVARCHAR(200) = ''  
  
   DECLARE @Temp_BatchPVal TABLE (  
   [filename]  NVARCHAR(255) DEFAULT '',  
   [PVal1]     NVARCHAR(200) DEFAULT '',  
   [PVal2]     NVARCHAR(200) DEFAULT '',  
   [PVal3]     NVARCHAR(200) DEFAULT '',  
   [PVal4]     NVARCHAR(200) DEFAULT '',  
   [PVal5]     NVARCHAR(200) DEFAULT '',  
   [PVal6]     NVARCHAR(200) DEFAULT '',  
   [PVal7]     NVARCHAR(200) DEFAULT '',  
   [PVal8]     NVARCHAR(200) DEFAULT '',  
   [PVal9]     NVARCHAR(200) DEFAULT '',  
   [PVal10]    NVARCHAR(200) DEFAULT ''  
   )  
  
   /*********************************************/  
   /* Variables Declaration (End)               */  
   /*********************************************/  
  
 IF @b_Debug = 1  
   BEGIN  
      PRINT '[dbo].[isp_EXG_FilterCondition6]: Start...'  
      PRINT '[dbo].[isp_EXG_FilterCondition6]: '  
          + ' @c_Username=' + ISNULL(RTRIM(@c_Username), '')  
          + ' @n_EXG_Hdr_ID=' + ISNULL(RTRIM(@n_EXG_Hdr_ID), '')  
          + ',@c_FileNameFormat='   + ISNULL(RTRIM(@c_FileNameFormat), '')  
          + ',@c_ParamVal1='  + ISNULL(RTRIM(@c_ParamVal1), '')  
          + ',@c_ParamVal2='  + ISNULL(RTRIM(@c_ParamVal2), '')  
          + ',@c_ParamVal3='  + ISNULL(RTRIM(@c_ParamVal3), '')  
          + ',@c_ParamVal4='  + ISNULL(RTRIM(@c_ParamVal4), '')  
          + ',@c_ParamVal5='  + ISNULL(RTRIM(@c_ParamVal5), '')  
          + ',@c_ParamVal6='  + ISNULL(RTRIM(@c_ParamVal6), '')  
          + ',@c_ParamVal7='  + ISNULL(RTRIM(@c_ParamVal7), '')  
          + ',@c_ParamVal8='  + ISNULL(RTRIM(@c_ParamVal8), '')  
          + ',@c_ParamVal9='  + ISNULL(RTRIM(@c_ParamVal9), '')  
          + ',@c_ParamVal10=' + ISNULL(RTRIM(@c_ParamVal10), '')  
   END  
  
   IF @n_EXG_Hdr_ID <= 0  
   BEGIN  
         SET @n_Err = 210001  
         SET @c_ErrMsg = 'Invalid EXG Hdr ID. (isp_EXG_FilterCondition6)'  
         SET @n_Continue = 3  
         GOTO QUIT  
   END  
  
   SELECT @c_TargetFolder = TargetFolder  
         ,@c_FileExt = FileExtension  
         ,@c_Delimiter = Delimiter  
         ,@b_RetryFlag = RetryFlag  
   FROM [GTApps].[dbo].[EXG_Hdr] WITH (NOLOCK)  
   WHERE EXG_Hdr_ID = @n_EXG_Hdr_ID  
  
   BEGIN TRAN  
   BEGIN TRY  
      /*******************Construct FileName START******************/  
      IF (ISNULL(RTRIM(@c_ParamVal1), '') = '')  
      BEGIN  
         SET @n_Err = 210002  
         SET @c_ErrMsg = ' StorerKey cannot be null. - (isp_EXG_FilterCondition6)'  
     
         IF @b_Debug = 1  
         BEGIN  
            PRINT '[isp_EXG_FilterCondition6]: Execute SP Name Failed...' + ' @c_ErrMsg=' + @c_ErrMsg  
         END  
         GOTO QUIT  
      END  
  
      IF (ISNULL(RTRIM(@c_ParamVal2), '') = '')  
      BEGIN  
         SET @n_Err = 210003  
         SET @c_ErrMsg = ' ListName cannot be null. - (isp_EXG_FilterCondition6)'  
     
         IF @b_Debug = 1  
         BEGIN  
            PRINT '[isp_EXG_FilterCondition6]: Execute SP Name Failed...' + ' @c_ErrMsg=' + @c_ErrMsg  
         END  
         GOTO QUIT  
      END 
      
      IF (ISNULL(RTRIM(@c_ParamVal3), '') = '')  
      BEGIN  
         SET @n_Err = 210004  
         SET @c_ErrMsg = ' Code cannot be null. - (isp_EXG_FilterCondition6)'  
     
         IF @b_Debug = 1  
         BEGIN  
            PRINT '[isp_EXG_FilterCondition6]: Execute SP Name Failed...' + ' @c_ErrMsg=' + @c_ErrMsg  
         END  
         GOTO QUIT  
      END 
   
      IF EXISTS (SELECT 1 
                 FROM dbo.transmitlog3 AS t   WITH (NOLOCK)
                 JOIN dbo.orders       AS o   WITH (NOLOCK) ON t.key1          = o.orderkey
                 JOIN dbo.LoadPlan     AS l   WITH (NOLOCK) ON l.LoadKey       = o.LoadKey 
                 JOIN dbo.packheader   AS p   WITH (NOLOCK) ON p.orderkey      = o.orderkey
                 JOIN dbo.packdetail   AS pd  WITH (NOLOCK) ON pd.pickslipno   = p.pickslipno
                 JOIN dbo.storer       AS c   WITH (NOLOCK) ON o.consigneekey  = c.storerkey
                 WHERE t.key3         = @c_ParamVal1 
                 AND   t.tablename    = @c_ParamVal3
                 AND   t.transmitflag = '0'         -- CASE @Debug WHEN 0 THEN '0' ELSE '9' END
                 AND   c.Email1       <> ''
                 AND   o.Status       IN ( CASE WHEN @c_ParamVal1 <> 'NIKESG' THEN '5' END, '9' )
                 AND   l.Status       IN ( CASE WHEN @c_ParamVal1 <> 'NIKESG' THEN '5' END, '9' )
                 )  
      BEGIN  
         INSERT INTO @Temp_BatchPVal ([filename]  
                                    , [PVal1]  
                                    , [PVal2]  
                                    , [PVal3]  
                                    , [PVal4]  
                                    , [PVal5])  
            SELECT CONCAT(@c_ParamVal1 
                        , '_'  
                        , o.ConsigneeKey  
                        , '_' 
                        , CONVERT(CHAR(8),o.deliverydate,112)
                        , @c_FileExt)  
                  , @c_ParamVal1  
                  , @c_ParamVal2  
                  , @c_ParamVal3  
                  , o.ConsigneeKey  
                  , CONVERT(CHAR(8),o.deliverydate,112)  
            FROM dbo.TRANSMITLOG3 AS t  WITH (NOLOCK)
            JOIN dbo.orders       AS o  WITH (NOLOCK) ON t.key1          = o.orderkey
            JOIN dbo.LoadPlan     AS l  WITH (NOLOCK) ON l.LoadKey       = o.LoadKey     
            JOIN dbo.packheader   AS p  WITH (NOLOCK) ON p.orderkey      = o.orderkey 
            JOIN dbo.packdetail   AS pd WITH (NOLOCK) ON pd.pickslipno   = p.pickslipno
            JOIN dbo.storer       AS c  WITH (NOLOCK) ON o.consigneekey  = c.storerkey
            WHERE t.key3         = @c_ParamVal1 
            AND   t.tablename    = @c_ParamVal3
            AND   t.transmitflag = '0'         -- CASE @Debug WHEN 0 THEN '0' ELSE '9' END
            AND   c.Email1       <> ''
            AND   o.Status       IN ( CASE WHEN @c_ParamVal1 <> 'NIKESG' THEN '5' END, '9' ) --KH04
            AND   l.Status       IN ( CASE WHEN @c_ParamVal1 <> 'NIKESG' THEN '5' END, '9' ) --KH07
            GROUP BY o.ConsigneeKey, o.deliverydate
      END  
      /*******************Construct FileName END******************/  
  
STARTCURSOR:    
  
      DECLARE C_FILEKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT [filename]  
           , [PVal1]  
           , [PVal2]   
           , [PVal3]   
           , [PVal4]   
           , [PVal5]   
           , [PVal6]   
           , [PVal7]   
           , [PVal8]   
           , [PVal9]   
           , [PVal10]  
      FROM @Temp_BatchPVal  
  
      OPEN C_FILEKEY  
      FETCH NEXT FROM C_FILEKEY INTO  @c_FileName  
                                    , @c_ValidPVal1   
                                    , @c_ValidPVal2   
                                    , @c_ValidPVal3   
                                    , @c_ValidPVal4   
                                    , @c_ValidPVal5   
                                    , @c_ValidPVal6   
                                    , @c_ValidPVal7   
                                    , @c_ValidPVal8   
                                    , @c_ValidPVal9   
                                    , @c_ValidPVal10  
      WHILE(@@FETCH_STATUS <> -1)  
      BEGIN  
         INSERT INTO [dbo].[EXG_FileHdr] (EXG_Hdr_ID, [TargetFolder], [filename], [status],  
         ParamVal1,ParamVal2,ParamVal3,ParamVal4,ParamVal5,ParamVal6,ParamVal7,ParamVal8,ParamVal9,ParamVal10, Delimiter, RetryFlag, AddWho, EditWho)  
         VALUES (@n_EXG_Hdr_ID, @c_TargetFolder, @c_FileName, 'W',  
         @c_ValidPVal1, @c_ValidPVal2, @c_ValidPVal3, @c_ValidPVal4, @c_ValidPVal5,  
         @c_ValidPVal6, @c_ValidPVal7, @c_ValidPVal8, @c_ValidPVal9, @c_ValidPVal10, @c_Delimiter, @b_RetryFlag, @c_Username, @c_Username)  
  
         SELECT @n_FileKey = SCOPE_IDENTITY();  
  
         SET @c_FileKeyList += CONVERT(NVARCHAR(10), @n_FileKey)  
         
         UPDATE [dbo].[EXG_FileHdr] WITH (ROWLOCK)
         SET [filename] = CONCAT(@c_ParamVal1 
                        , '_'  
                        , @c_ValidPVal4
                        , '_' 
                        , @c_ValidPVal5
                        , '_'
                        , @n_FileKey
                        , @c_FileExt) 
         WHERE file_key = @n_FileKey

         UPDATE t WITH (ROWLOCK)   
         SET transmitflag  = '1'
         FROM dbo.transmitlog3 AS t
         JOIN dbo.orders       AS o  WITH (NOLOCK) ON t.key1        = o.orderkey
         JOIN dbo.LoadPlan     AS l  WITH (NOLOCK) ON l.LoadKey     = o.LoadKey     --KH07
         JOIN dbo.packheader   AS p  WITH (NOLOCK) ON p.orderkey    = o.orderkey    --KH05
         JOIN dbo.packdetail   AS pd WITH (NOLOCK) ON pd.pickslipno = p.pickslipno
         JOIN dbo.storer       AS c  WITH (NOLOCK) ON o.consigneekey= c.storerkey
         WHERE t.key3         = @c_ParamVal1 
         AND   t.tablename    = @c_ParamVal3
         AND   t.transmitflag= '0'
         --AND   c.Email1      <> ''
         AND   o.Status       IN ( CASE WHEN @c_ParamVal1 <> 'NIKESG' THEN '5' END, '9' ) --KH05
         AND   l.Status       IN ( CASE WHEN @c_ParamVal1 <> 'NIKESG' THEN '5' END, '9' ) --KH07
         AND o.ConsigneeKey   = @c_ValidPVal4
         AND o.deliverydate   = @c_ValidPVal5

         FETCH NEXT FROM C_FILEKEY INTO   @c_FileName  
                                        , @c_ValidPVal1   
                                        , @c_ValidPVal2   
                                        , @c_ValidPVal3   
                                        , @c_ValidPVal4   
                                        , @c_ValidPVal5   
                                        , @c_ValidPVal6   
                                        , @c_ValidPVal7   
                                        , @c_ValidPVal8   
                                        , @c_ValidPVal9   
                                        , @c_ValidPVal10  
  
         IF @@FETCH_STATUS <> -1  
         BEGIN  
            SET @c_FileKeyList += ', '  
         END  
      END  
      CLOSE C_FILEKEY    
      DEALLOCATE C_FILEKEY  
  
   END TRY  
   BEGIN CATCH   
      WHILE @@TRANCOUNT > 0  
         ROLLBACK TRAN  
           
      SELECT @n_ITFErr = ERROR_NUMBER(), @c_ITFErrMsg = ERROR_MESSAGE()  
           
      SET @n_Err = @n_ITFErr  
      SET @c_ErrMsg = LTRIM(RTRIM(@c_ITFErrMsg)) + ' (isp_EXG_FilterCondition6)'  
                 
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_EXG_FilterCondition6]: Execute SP Name Failed...'   
               + ' @c_ErrMsg=' + @c_ErrMsg  
      END  
      GOTO QUIT  
   END CATCH  
  
QUIT:  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   WHILE @@TRANCOUNT < @n_StartTCnt        
      BEGIN TRAN   
  
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_success = 0        
      IF @@TRANCOUNT > @n_StartTCnt        
      BEGIN                 
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartTCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END     
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_FilterCondition6]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_FilterCondition6]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END  
  
      RETURN        
   END        
   ELSE        
   BEGIN  
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''   
      BEGIN  
         SELECT @b_Success = 0  
      END  
      ELSE  
      BEGIN   
         SELECT @b_Success = 1   
      END          
  
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END       
        
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_FilterCondition6]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_FilterCondition6]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/      
END --End Procedure

GO