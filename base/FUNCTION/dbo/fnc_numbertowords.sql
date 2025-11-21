SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************************************************/  
/* Function       : fnc_NumberToWords                                                                        */  
/* Copyright      : LFL                                                                                      */  
/*                                                                                                           */  
/* Purpose: Return Number in words                                                                           */  
/*                                                                                                           */  
/*                                                                                                           */  
/* Usage: SELECT * from dbo.fnc_NumberToWords(number,word prefix,number surfix, decimal surfix, word surfix) */  
/*                                                                                                           */  
/* Modifications log:                                                                                        */  
/*                                                                                                           */  
/* Date         Rev  Author     Purposes                                                                     */  
/* 02-OCT-2020  1.1  CSCHONG    WMS-15196 Fix digit more than 10 with last digit 0 show ZERO (CS01)          */
/* 13-Nov-2020  1.2  WLChooi    WMS-15452 Fix Decimal to Words - 2 d.p. (WL01)                               */
/*************************************************************************************************************/  
  
CREATE FUNCTION [dbo].[fnc_NumberToWords](@n_Number AS FLOAT, @c_WordPrefix NVARCHAR(100), @c_NumberSurfix NVARCHAR(100), @c_DecimalSurfix NVARCHAR(100), @c_WordSurfix NVARCHAR(100))  
  
    RETURNS VARCHAR(1024)  
  
AS  
  
BEGIN   
      DECLARE @n_NumberPart BIGINT   
      DECLARE @n_DecimalPart BIGINT   
        
      SET @n_NumberPart = CAST(@n_Number AS BIGINT)  
      --SET @n_DecimalPart = CAST(REPLACE(CAST(@n_Number - @n_NumberPart AS NVARCHAR),'0.','') AS BIGINT)   --WL01  
      SET @n_DecimalPart = CAST(LEFT(REPLACE(CAST(@n_Number - @n_NumberPart AS NVARCHAR),'0.','') + '0', 2) AS BIGINT)   --WL01
                                                                                                                         --  
      DECLARE @Below20 TABLE (ID int identity(0,1), Word varchar(32))  
  
      DECLARE @Below100 TABLE (ID int identity(2,1), Word varchar(32))  
  
      INSERT @Below20 (Word) VALUES  
  
                        ( 'Zero'), ('One'),( 'Two' ), ( 'Three'),   
  
                        ( 'Four' ), ( 'Five' ), ( 'Six' ), ( 'Seven' ),  
  
                        ( 'Eight'), ( 'Nine'), ( 'Ten'), ( 'Eleven' ),  
  
                        ( 'Twelve' ), ( 'Thirteen' ), ( 'Fourteen'),  
  
                        ( 'Fifteen' ), ('Sixteen' ), ( 'Seventeen'),  
  
                        ('Eighteen' ), ( 'Nineteen' )  
  
       INSERT @Below100 VALUES ('Twenty'), ('Thirty'),('Forty'), ('Fifty'),  
  
                               ('Sixty'), ('Seventy'), ('Eighty'), ('Ninety')  
 

DECLARE @c_NumberInWords varchar(1024) =  
  
(  
  
  SELECT Case  
  
    WHEN @n_NumberPart = 0 THEN  'Zero' --ORG ''  
  
    WHEN @n_NumberPart BETWEEN 1 AND 19  
  
      THEN (SELECT Word FROM @Below20 WHERE ID=@n_NumberPart)  
  
   WHEN @n_NumberPart BETWEEN 20 AND 99    
  
     THEN  (SELECT Word FROM @Below100 WHERE ID=@n_NumberPart/10)+ ' '+ --ORG '-' +  
  
           CASE WHEN @n_NumberPart % 10 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 10,'','','','') ELSE '' END  --CS01
  
   WHEN @n_NumberPart BETWEEN 100 AND 999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 100,'','','',''))+' Hundred '+  
  
        CASE WHEN @n_NumberPart % 100 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 100,'','','','')  ELSE '' END  --CS01
  
   WHEN @n_NumberPart BETWEEN 1000 AND 999999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 1000,'','','',''))+' Thousand '+  
  
        CASE WHEN @n_NumberPart % 1000 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 1000,'','','','')  ELSE '' END --CS01 
  
   WHEN @n_NumberPart BETWEEN 1000000 AND 999999999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 1000000,'','','',''))+' Million '+  
  
        CASE WHEN @n_NumberPart % 1000000 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 1000000,'','','','')  ELSE '' END --CS01
  
   WHEN @n_NumberPart BETWEEN 1000000000 AND 999999999999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 1000000000,'','','',''))+' Billion '+  
  
          CASE WHEN @n_NumberPart % 1000000000 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 1000000000,'','','','')  ELSE '' END --CS01
  
   WHEN @n_NumberPart BETWEEN 1000000000000 AND 999999999999999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 1000000000000,'','','',''))+' Trillion '+  
  
         CASE WHEN @n_NumberPart % 1000000000000 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 1000000000000,'','','','')  ELSE '' END --CS01
  
  WHEN @n_NumberPart BETWEEN 1000000000000000 AND 999999999999999999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 1000000000000000,'','','',''))+' Quadrillion '+  
  
         CASE WHEN @n_NumberPart % 1000000000000000 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 1000000000000000,'','','','') ELSE '' END --CS01 
  
  WHEN @n_NumberPart BETWEEN 1000000000000000000 AND 999999999999999999999    
  
     THEN  (dbo.fnc_NumberToWords( @n_NumberPart / 1000000000000000000,'','','',''))+' Quintillion '+  
  
         CASE WHEN @n_NumberPart % 1000000000000000000 <> 0 THEN dbo.fnc_NumberToWords( @n_NumberPart % 1000000000000000000,'','','','')  ELSE '' END  --CS01
  
        ELSE ' INVALID INPUT' END  
  
)  
  
IF LEN(@c_NumberInWords) > 0   
BEGIN  
   SELECT @c_NumberInWords = RTRIM(@c_NumberInWords)  
  
   IF ISNULL(@c_WordPrefix,'') <> ''  
      SELECT @c_NumberInWords = RTRIM(@c_WordPrefix) + ' ' + LTRIM(RTRIM(@c_NumberInWords))   
  
   IF ISNULL(@c_NumberSurfix,'') <> ''  
      SELECT @c_NumberInWords = RTRIM(@c_NumberInWords) + ' ' + LTRIM(RTRIM(@c_NumberSurfix))   
END     
  
IF @n_DecimalPart > 0   
BEGIN  
  IF @n_NumberPart > 0  
    SELECT @c_NumberInWords = ISNULL(@c_NumberInWords,'') + ' And ' + dbo.fnc_NumberToWords(@n_DecimalPart,'','','','')   
  ELSE  
    SELECT @c_NumberInWords = dbo.fnc_NumberToWords(@n_DecimalPart,'','','','')   
  
  IF ISNULL(@c_DecimalSurfix,'') <> ''  
     SELECT @c_NumberInWords = RTRIM(@c_NumberInWords) + ' ' + LTRIM(RTRIM(@c_DecimalSurfix))   
END  
  
IF ISNULL(@c_WordSurfix,'') <> ''  
   SELECT @c_NumberInWords = RTRIM(@c_NumberInWords) + ' ' + LTRIM(RTRIM(@c_WordSurfix))   
  
RETURN @c_NumberInWords  
  
END  

GO