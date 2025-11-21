SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispCheckKeyExists                                  */  
/* Creation Date: 10-Jun-2003                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Check if the keys are existed from the related table.       */  
/*          - Have key values to pass in for verification.              */  
/*                                                                      */  
/* Called By:  Any other related Store Procedures.                      */  
/*                                                                      */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 22-Aug-2007  YokeBeen   - Modified in order to have five key values  */  
/*                           to be passed in for verification.          */  
/*                         - To handle SQL 2005 compatibility.          */  
/*                                                                      */   
/************************************************************************/  
  
CREATE PROC [dbo].[ispCheckKeyExists]  
   @c_DBName    NVARCHAR(20),  
   @c_TableName NVARCHAR(40),  
   @c_Key1      NVARCHAR(30),  
   @c_KeyValue1 NVARCHAR(30),  
   @c_Key2      NVARCHAR(150),  
   @c_KeyValue2 NVARCHAR(150),  
   @b_Success   int OUTPUT,   
   @c_Key3      NVARCHAR(30) = '' ,  
   @c_KeyValue3 NVARCHAR(30) = '' ,  
   @c_Key4      NVARCHAR(30) = '' ,  
   @c_KeyValue4 NVARCHAR(30) = '' ,  
   @c_Key5      NVARCHAR(30) = '' ,  
   @c_KeyValue5 NVARCHAR(30) = ''   
AS  
BEGIN  
   SET ROWCOUNT 1  
  
   DECLARE @c_SQLStatement nvarchar(512)  
         , @b_debug        int  
         , @n_RowFound     int   
         , @c_Quotation1   NVARCHAR(1)  
         , @c_Quotation2   NVARCHAR(2)  
  
   SET @b_Success = 1   
   SET @b_debug = 0   
   SET @n_RowFound = '0'  
   SET @c_Quotation1 = ''''  
   SET @c_Quotation2 = ''''''  
  
   IF ISNULL(RTRIM(@c_Key1),'') = ''  
   BEGIN  
      SELECT @b_Success = 0  
      RETURN  
   END  
  
   IF @b_Success = 1  
   BEGIN  
      IF CHARINDEX(@c_Quotation1, @c_KeyValue1) > 0   
         SET @c_KeyValue1 = REPLACE(@c_KeyValue1, @c_Quotation1, @c_Quotation2)  
  
      SELECT @c_SQLStatement = N'SELECT @n_RowFound = COUNT(*)  FROM '   
      SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' ' + ISNULL(RTRIM(@c_DBName), '') + '.dbo.'   
            + RTRIM(@c_TableName) + ' WITH (NOLOCK) WHERE ' + RTRIM(@c_Key1) + ' = ''' + RTRIM(@c_KeyValue1) + ''''   
        
      IF ISNULL(RTRIM(@c_Key2),'') <> ''  
      BEGIN  
         DECLARE @c_inputkey NVARCHAR(30)  
               , @c_inputkeyvalue NVARCHAR(30)  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT CHARINDEX('|', @c_Key2), @c_Key2, @c_KeyValue2  
         END  
  
         IF CHARINDEX('|', @c_Key2) > 0   
         BEGIN  
            WHILE CHARINDEX('|', @c_Key2) > 0  
            BEGIN  
               SELECT @c_inputkey = LEFT(@c_Key2, CHARINDEX('|', @c_Key2) - 1)  
               SELECT @c_inputkeyvalue = LEFT(@c_KeyValue2, CHARINDEX('|', @c_KeyValue2) - 1)  
               SELECT @c_Key2 = SUBSTRING(@c_Key2, CHARINDEX('|', @c_Key2) + 1, len(@c_Key2))  
               SELECT @c_KeyValue2 = SUBSTRING(@c_KeyValue2, CHARINDEX('|', @c_KeyValue2) + 1, len(@c_KeyValue2))  
  
               IF @b_debug = 1                 BEGIN  
                  SELECT @c_inputkey, @c_inputkeyvalue, @c_Key2  
               END  
  
               SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' AND ' + RTRIM(@c_inputkey) + ' = N'''   
                    + RTRIM(@c_inputkeyvalue) + ''''   
            END  
         END  
         ELSE  
         BEGIN   
            IF CHARINDEX(@c_Quotation1, @c_KeyValue2) > 0   
               SET @c_KeyValue2 = REPLACE(@c_KeyValue2, @c_Quotation1, @c_Quotation2)  
  
            SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' AND ' + RTRIM(@c_Key2) + ' = N'''   
                 + RTRIM(@c_KeyValue2) + ''''   
         END  
      END -- IF ISNULL(RTRIM(@c_Key2),'') <> ''  
  
      IF ISNULL(RTRIM(@c_Key3),'') <> ''  
      BEGIN  
         IF CHARINDEX(@c_Quotation1, @c_KeyValue3) > 0   
            SET @c_KeyValue3 = REPLACE(@c_KeyValue3, @c_Quotation1, @c_Quotation2)  
  
         SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' AND ' + RTRIM(@c_Key3) + ' = N'''   
              + RTRIM(@c_KeyValue3) + ''''   
      END -- IF ISNULL(RTRIM(@c_Key3),'') <> ''  
  
      IF ISNULL(RTRIM(@c_Key4),'') <> ''  
      BEGIN  
         IF CHARINDEX(@c_Quotation1, @c_KeyValue4) > 0   
            SET @c_KeyValue4 = REPLACE(@c_KeyValue4, @c_Quotation1, @c_Quotation2)  
  
         SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' AND ' + RTRIM(@c_Key4) + ' = N'''   
              + RTRIM(@c_KeyValue4) + ''''   
      END -- IF ISNULL(RTRIM(@c_Key4),'') <> ''  
  
      IF ISNULL(RTRIM(@c_Key5),'') <> ''  
      BEGIN  
         IF CHARINDEX(@c_Quotation1, @c_KeyValue5) > 0   
            SET @c_KeyValue3 = REPLACE(@c_KeyValue5, @c_Quotation1, @c_Quotation2)  
  
         SELECT @c_SQLStatement = RTRIM(@c_SQLStatement) + ' AND ' + RTRIM(@c_Key5) + ' = N'''   
              + RTRIM(@c_KeyValue5) + ''''   
      END -- IF ISNULL(RTRIM(@c_Key5),'') <> ''  
  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT @c_SQLStatement  
      END  
        
      SELECT @n_RowFound = 0  
      EXEC sp_executesql @c_SQLStatement, N'@n_RowFound int output', @n_RowFound OUTPUT  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT @n_RowFound  
      END  
     
      IF ISNULL(RTRIM(@n_RowFound),0) = 0  
         SELECT @b_Success = 0  
   END  
END -- procedure

GO