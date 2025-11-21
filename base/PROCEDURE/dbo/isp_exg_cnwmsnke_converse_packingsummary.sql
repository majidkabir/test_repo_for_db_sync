SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_EXG_CNWMSNKE_CONVERSE_PackingSummary            */  
/* Creation Date: 08 Jul 2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GHChan                                                    */  
/*                                                                       */  
/* Purpose: Excel Generator CONVERSE PackingSummary Sheet Report         */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 08-Jul-2020   GHChan   1.0  Initial Development                       */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]  
(  @n_FileKey     INT           = 0  
,  @n_EXG_Hdr_ID  INT     = 0  
,  @c_FileName    NVARCHAR(200) = ''  
,  @c_SheetName   NVARCHAR(100) = ''  
,  @c_Delimiter   NVARCHAR(2)   = ''  
,  @c_ParamVal1   NVARCHAR(200) = ''  
,  @c_ParamVal2   NVARCHAR(200) = ''  
,  @c_ParamVal3   NVARCHAR(200) = ''  
,  @c_ParamVal4   NVARCHAR(200) = ''  
,  @c_ParamVal5   NVARCHAR(200) = ''  
,  @c_ParamVal6   NVARCHAR(200) = ''  
,  @c_ParamVal7   NVARCHAR(200) = ''  
,  @c_ParamVal8   NVARCHAR(200) = ''  
,  @c_ParamVal9   NVARCHAR(200) = ''  
,  @c_ParamVal10  NVARCHAR(200) = ''  
,  @b_Debug       INT           = 0  
,  @b_Success     INT           = 1    OUTPUT  
,  @n_Err         INT           = 0    OUTPUT  
,  @c_ErrMsg      NVARCHAR(250) = ''   OUTPUT   
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
  
   DECLARE @n_Continue      INT = 1  
         , @n_StartTcnt     INT = @@TRANCOUNT  
         , @SQL             NVARCHAR(MAX) = ''  
  
         , @c_Size1         CHAR(100) = ''  
         , @c_CONCATCOL     NVARCHAR(3000) = ''  
         , @c_CONCATVAL     NVARCHAR(3000) = ''  
  
   IF OBJECT_ID('tempdb..##tempConvReport') IS NOT NULL DROP TABLE ##tempConvReport  
  
   CREATE TABLE ##tempConvReport(   
      Mbolkey        CHAR(10),   
      ExternOrderkey CHAR(20),   
      Style          CHAR(50),   
      Color          CHAR(50),   
      Size1          CHAR(100),   
      Qty            INT  
   )  
  
   /*********************************************/  
   /* Variables Declaration (End)               */  
   /*********************************************/  
  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]: Start...'  
      PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]: '  
          + ',@n_FileKey='      + ISNULL(RTRIM(@n_FileKey), '')  
      + ',@n_EXG_Hdr_ID='   + ISNULL(RTRIM(@n_EXG_Hdr_ID), '')  
          + ',@c_FileName='     + ISNULL(RTRIM(@c_FileName), '')  
          + ',@c_SheetName='    + ISNULL(RTRIM(@c_SheetName), '')  
          + ',@c_Delimiter='    + ISNULL(RTRIM(@c_Delimiter), '')  
          + ',@c_ParamVal1='    + ISNULL(RTRIM(@c_ParamVal1), '')  
          + ',@c_ParamVal2='    + ISNULL(RTRIM(@c_ParamVal2), '')  
          + ',@c_ParamVal3='    + ISNULL(RTRIM(@c_ParamVal3), '')  
          + ',@c_ParamVal4='    + ISNULL(RTRIM(@c_ParamVal4), '')  
          + ',@c_ParamVal5='    + ISNULL(RTRIM(@c_ParamVal5), '')  
          + ',@c_ParamVal6='    + ISNULL(RTRIM(@c_ParamVal6), '')  
          + ',@c_ParamVal7='    + ISNULL(RTRIM(@c_ParamVal7), '')  
          + ',@c_ParamVal8='    + ISNULL(RTRIM(@c_ParamVal8), '')  
          + ',@c_ParamVal9='    + ISNULL(RTRIM(@c_ParamVal9), '')  
          + ',@c_ParamVal10='   + ISNULL(RTRIM(@c_ParamVal10), '')  
   END  
  
   BEGIN TRAN  
   BEGIN TRY  
      insert into ##tempConvReport(Mbolkey,  
      ExternOrderkey,  
      Style,  
      Color,  
      Size1,  
      Qty)   
      select t1.Mbolkey,   
      t1.ExternOrderkey,  
      t3.Style,   
      case   
         when t1.stop='20' then '' else t3.Color   
      end as Color,   
      '<dq>'+ case   
               when left(ltrim(rtrim(t3.size)),1)='0' then cast(cast(cast(t3.Size as int) as float)/10 as varchar(5))   
               when (t3.measurement = '' or t3.measurement='U') then t3.Size else t3.measurement   
           end,   
      sum(t2.ShippedQty+t2.QtyPicked) as Qty   
      from dbo.Orders as t1 (nolock)   
      inner join dbo.Orderdetail as t2(nolock) on t1.Orderkey=t2.Orderkey   
      inner join dbo.SKU as t3(nolock) on t2.Storerkey=t3.Storerkey and t2.SKU=t3.SKU   
      where t1.Storerkey=@c_ParamVal1   
      and t1.Status in('5','9')   
      and t1.Mbolkey=@c_ParamVal2   
      and t2.ShippedQty+t2.QtyPicked>0   
      group by t1.Mbolkey,   
      t1.ExternOrderkey,  
      t3.Style,   
      case   
         when t1.stop='20' then '' else t3.Color   
         end,   
      '<dq>' + case   
               when left(ltrim(rtrim(t3.size)),1)='0' then cast(cast(cast(t3.Size as int) as float)/10 as varchar(5))   
               when (t3.measurement = '' or t3.measurement='U') then t3.Size else t3.measurement   
            end   
      order by t1.externorderkey,  
      t3.Style,  
      case   
         when t1.stop='20' then '' else t3.Color   
         end,  
      '<dq>' + case   
               when left(ltrim(rtrim(t3.size)),1)='0' then cast(cast(cast(t3.Size as int) as float)/10 as varchar(5))   
               when (t3.measurement = '' or t3.measurement='U') then t3.Size else t3.measurement   
            end   
  
      IF NOT EXISTS(SELECT 1 FROM ##tempConvReport)  
      BEGIN  
         SET @n_Err = 200505  
         SET @c_ErrMsg = 'No records have been found! (isp_EXG_CNWMSNKE_CONVERSE_PackingSummary)'  
         SET @n_Continue = 3  
         GOTO QUIT  
      END  
  
      -- START CURSOR TO CONCAT ALL THE COLUMNS  
      SET @c_CONCATCOL = '"Mbolkey"' + @c_Delimiter   
                       + '"ExternOrderkey"' + @c_Delimiter   
                       + '"Style"' + @c_Delimiter  
                       + '"Color"' + @c_Delimiter  
                       + '"SubTotal"' + @c_Delimiter   
        
     SET @c_CONCATVAL = '''"'',Mbolkey,''"' + @c_Delimiter   
                       + '"'',ExternOrderkey,''"' + @c_Delimiter   
                       + '"'',Style,''"' + @c_Delimiter   
                       + '"'',Color,''"' + @c_Delimiter   
                       + '"'',SubTotal,''"' + @c_Delimiter + '"'','   
  
      DECLARE C_APPENDCOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT Size1 FROM ##tempConvReport ORDER BY Size1  
  
      OPEN C_APPENDCOL  
      FETCH NEXT FROM C_APPENDCOL INTO  @c_Size1  
  
      WHILE(@@FETCH_STATUS <> -1)  
      BEGIN  
           
         SET @c_CONCATCOL += '"' + LTRIM(RTRIM(@c_Size1)) + '"'  
         SET @c_CONCATVAL += '[' + LTRIM(RTRIM(@c_Size1)) + ']'  
  
         FETCH NEXT FROM C_APPENDCOL INTO   @c_Size1  
  
         IF (@@FETCH_STATUS <> -1)  
         BEGIN  
            SET @c_CONCATCOL += @c_Delimiter  
            SET @c_CONCATVAL += ',''"' + @c_Delimiter + '"'','  
         END  
         ELSE  
         BEGIN  
            SET @c_CONCATVAL += ',''"'''  
         END  
      END  
      CLOSE C_APPENDCOL    
      DEALLOCATE C_APPENDCOL  
  
      INSERT INTO [dbo].[EXG_FileDet](  
           file_key  
         , EXG_Hdr_ID  
         , [FileName]  
         , SheetName  
         , [Status]  
         , LineText1)  
      SELECT  @n_FileKey  
      , @n_EXG_Hdr_ID   
      , @c_FileName  
      , @c_SheetName  
      , 'W'  
      , @c_CONCATCOL  
  
      set @SQL='Select Mbolkey,ExternOrderkey,Style,Color,sum(qty) as SubTotal,'   
      select @SQL=@SQL+'sum(case when size1='''+ltrim(rtrim(Size1))+''' then qty else 0 end)['+ltrim(rtrim(Size1))+'],'   
      from (select distinct top 1000 Size1 from ##tempConvReport order by Size1)a    
  
      set @SQL =left(@SQL,len(@SQL)-1)+' from ##tempConvReport group by Mbolkey,ExternOrderkey,Style,Color '   
                +' Union all Select ''Total'','''','''','''',sum(qty) as Total,'   
  
      select @SQL=@SQL+'sum(case when size1='''+ltrim(rtrim(Size1))+''' then qty else 0 end)['+ltrim(rtrim(Size1))+'],'   
      from (select distinct top 1000 Size1 from ##tempConvReport order by Size1)a    
   
      set @SQL =left(@SQL,len(@SQL)-1)+' from ##tempConvReport order by 1 ' -- order by index of the column in the select statement (MbolKey)  
  
      SET @SQL = 'INSERT INTO [dbo].[EXG_FileDet] (file_key, EXG_Hdr_ID, [FileName], SheetName, [Status], LineText1) '  
               + 'SELECT '   
               + CAST(@n_FileKey AS nvarchar(10))   
               + ', '   
               + CAST(@n_EXG_Hdr_ID AS nvarchar(10))  
               + ' , '''   
               + @c_FileName   
               + ''', '''   
               + @c_SheetName   
               + ''', ''W'', CONCAT('+@c_CONCATVAL+') AS LineText1 '  
               + 'FROM ('+@SQL+' OFFSET 0 ROWS) AS TEMP2'  
        
      IF @b_Debug = 1  
      BEGIN  
         PRINT @SQL  
         SELECT @SQL  
      END  
  
      EXEC(@SQL)  
  
   END TRY  
   BEGIN CATCH  
      SET @n_Err = ERROR_NUMBER();  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_CNWMSNKE_CONVERSE_PackingSummary)'  
      SET @n_Continue = 3  
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
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR(10)))  
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
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackingSummary]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR(10)))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/  
END --End Procedure  

GO