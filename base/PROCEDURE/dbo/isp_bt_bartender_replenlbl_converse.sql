SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

   
/******************************************************************************/         
/* Copyright: IDS                                                             */         
/* Purpose: BarTender Filter by ShipperKey                                    */         
/*                                                                            */         
/* Modifications log:                                                         */         
/*                                                                            */         
/* Date       Rev  Author     Purposes                                        */         
/* 2019-04-25 1.0  CSCHONG    Created (WMS-6438)                              */    
/******************************************************************************/        
          
CREATE PROC [dbo].[isp_BT_Bartender_REPLENLBL_CONVERSE]               
(  @c_Sparm01            NVARCHAR(250),      
   @c_Sparm02            NVARCHAR(250),      
   @c_Sparm03            NVARCHAR(250),      
   @c_Sparm04            NVARCHAR(250),      
   @c_Sparm05            NVARCHAR(250),      
   @c_Sparm06            NVARCHAR(250),      
   @c_Sparm07            NVARCHAR(250),      
   @c_Sparm08            NVARCHAR(250),      
   @c_Sparm09            NVARCHAR(250),      
   @c_Sparm10            NVARCHAR(250),
   @b_debug              INT = 0               
)              
AS              
BEGIN              
   SET NOCOUNT ON         
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF         
   SET CONCAT_NULL_YIELDS_NULL OFF        
                      
   DECLARE          
      @c_CarrierKey        NVARCHAR(15),            
      @c_CarrierName       NVARCHAR(30),           
      @c_ExternReceiptKey  NVARCHAR(20),      
      @c_SQL               NVARCHAR(4000),
      @c_SQLSORT           NVARCHAR(4000),
      @c_SQLJOIN           NVARCHAR(4000),
      @n_TTLCopy           INT,
      @c_ChkStatus         NVARCHAR(2),
      @c_ExecStatements    NVARCHAR(4000),   
      @c_ExecArguments     NVARCHAR(4000)     
      
    -- SET RowNo = 0     
    SET @c_SQL = ''  
    SET @n_TTLCopy = 1
      
    CREATE TABLE [#Result] (     
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                    
      [Col01] [NVARCHAR] (80) NULL,      
      [Col02] [NVARCHAR] (80) NULL,      
      [Col03] [NVARCHAR] (80) NULL,      
      [Col04] [NVARCHAR] (80) NULL,      
      [Col05] [NVARCHAR] (80) NULL,      
      [Col06] [NVARCHAR] (80) NULL,      
      [Col07] [NVARCHAR] (80) NULL,      
      [Col08] [NVARCHAR] (80) NULL,      
      [Col09] [NVARCHAR] (80) NULL,      
      [Col10] [NVARCHAR] (80) NULL,      
      [Col11] [NVARCHAR] (80) NULL,      
      [Col12] [NVARCHAR] (80) NULL,      
      [Col13] [NVARCHAR] (80) NULL,      
      [Col14] [NVARCHAR] (80) NULL,      
      [Col15] [NVARCHAR] (80) NULL,      
      [Col16] [NVARCHAR] (80) NULL,      
      [Col17] [NVARCHAR] (80) NULL,      
      [Col18] [NVARCHAR] (80) NULL,      
      [Col19] [NVARCHAR] (80) NULL,      
      [Col20] [NVARCHAR] (80) NULL,      
      [Col21] [NVARCHAR] (80) NULL,      
      [Col22] [NVARCHAR] (80) NULL,      
      [Col23] [NVARCHAR] (80) NULL,      
      [Col24] [NVARCHAR] (80) NULL,      
      [Col25] [NVARCHAR] (80) NULL,      
      [Col26] [NVARCHAR] (80) NULL,      
      [Col27] [NVARCHAR] (80) NULL,      
      [Col28] [NVARCHAR] (80) NULL,      
      [Col29] [NVARCHAR] (80) NULL,      
      [Col30] [NVARCHAR] (80) NULL,      
      [Col31] [NVARCHAR] (80) NULL,      
      [Col32] [NVARCHAR] (80) NULL,      
      [Col33] [NVARCHAR] (80) NULL,      
      [Col34] [NVARCHAR] (80) NULL,      
      [Col35] [NVARCHAR] (80) NULL,      
      [Col36] [NVARCHAR] (80) NULL,      
      [Col37] [NVARCHAR] (80) NULL,      
      [Col38] [NVARCHAR] (80) NULL,      
      [Col39] [NVARCHAR] (80) NULL,      
      [Col40] [NVARCHAR] (80) NULL,      
      [Col41] [NVARCHAR] (80) NULL,      
      [Col42] [NVARCHAR] (80) NULL,      
      [Col43] [NVARCHAR] (80) NULL,      
      [Col44] [NVARCHAR] (80) NULL,      
      [Col45] [NVARCHAR] (80) NULL,      
      [Col46] [NVARCHAR] (80) NULL,      
      [Col47] [NVARCHAR] (80) NULL,      
      [Col48] [NVARCHAR] (80) NULL,      
      [Col49] [NVARCHAR] (80) NULL,      
      [Col50] [NVARCHAR] (80) NULL,     
      [Col51] [NVARCHAR] (80) NULL,      
      [Col52] [NVARCHAR] (80) NULL,      
      [Col53] [NVARCHAR] (80) NULL,      
      [Col54] [NVARCHAR] (80) NULL,      
      [Col55] [NVARCHAR] (80) NULL,      
      [Col56] [NVARCHAR] (80) NULL,      
      [Col57] [NVARCHAR] (80) NULL,      
      [Col58] [NVARCHAR] (80) NULL,      
      [Col59] [NVARCHAR] (80) NULL,      
      [Col60] [NVARCHAR] (80) NULL     
     )      


  SET @c_SQLJOIN = +' SELECT TOP 1 PD.Dropid,PD.Loc,PD.SKU,'''' ,'    
             + CHAR(13) +   
             +' '''',P.Casecnt, RIGHT(PD.notes,13),'      --7
             + CHAR(13) + 
             +' '''','''','  --9
             + ' CASE WHEN PD.UOM=''2'' THEN (ORD.ExternOrderkey) ELSE '''' END ,'    --10
             + CHAR(13) +  
             +' PD.UOM, @c_Sparm01,S.Style,S.Color,S.Size,'''', '  --16
             + ''''',LEFT(PD.notes,1),P.PACKUOM1,SUM(PD.Qty), '   --20 
             + CHAR(13) +  
             + ' '''','''','
             + ' '''','''','''','''','''','''','''','''', '   
             + CHAR(13) +  
             +' '''','''','''','''','''','''','''','''','''','''','   
             + CHAR(13) +  
             +' '''','''','''','''','''','''','''','''','''','''', '   
             + CHAR(13) +   
             +' '''','''','''','''','''','''','''','''','''','''' '   
             + CHAR(13) +    
             + ' FROM PICKDETAIL PD WITH (NOLOCK) '
             + ' JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.Orderkey'
             + ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.storerkey AND S.SKU = PD.SKU '
             + ' JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey ' 
             + ' WHERE PD.Dropid = @c_Sparm02 '
             + ' AND PD.Storerkey= @c_Sparm07 '
             + ' GROUP BY PD.Dropid,PD.Loc,PD.SKU,RIGHT(PD.notes,13), CASE WHEN PD.UOM=''2'' THEN (ORD.ExternOrderkey) ELSE '''' END,'
             + ' PD.UOM,S.Style,S.Color,S.Size, LEFT(PD.notes,1),P.Casecnt,P.PACKUOM1'
   
            IF @b_debug='1'
            BEGIN
               PRINT @c_SQLJOIN  
            END        
      
     SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +   
                                   +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +   
                                   +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +   
                                   +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +   
                                   +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +   
                                   + ',Col55,Col56,Col57,Col58,Col59,Col60) '  

     SET @c_SQL = @c_SQL + @c_SQLJOIN

 
     -- EXEC sp_executesql @c_SQL  

     SET @c_ExecArguments = N'  @c_Sparm01           NVARCHAR(80)'   
                           + ', @c_Sparm02           NVARCHAR(80) '    
                           + ', @c_Sparm03           NVARCHAR(80)'  
                           + ', @c_Sparm04           NVARCHAR(80)' 
                           + ', @c_Sparm05           NVARCHAR(80)' 
                           + ', @c_Sparm06           NVARCHAR(80)' 
                           + ', @c_Sparm07           NVARCHAR(80)'  
                           
                         
                         
      EXEC sp_ExecuteSql     @c_SQL     
                      , @c_ExecArguments    
                      , @c_Sparm01
                      , @c_Sparm02  
                      , @c_Sparm03  
                      , @c_Sparm04
                      , @c_Sparm05  
                      , @c_Sparm06   
                      , @c_Sparm07    


   UPDATE #Result
   SET Col04 = substring(@c_Sparm03,1,charindex('|',@c_Sparm03)-1)
      ,Col05 = substring(@c_Sparm03,charindex('|',@c_Sparm03)+1,5)
      ,Col08 = substring(@c_Sparm04,1,charindex('|',@c_Sparm04)-1)
      ,Col09 = substring(@c_Sparm04,charindex('|',@c_Sparm04)+1,5)
      ,Col16 = substring(@c_Sparm05,1,charindex('|',@c_Sparm05)-1)
      ,Col17 = substring(@c_Sparm05,charindex('|',@c_Sparm05)+1,5)
      ,Col20 = substring(@c_Sparm06,1,charindex('|',@c_Sparm06)-1)
      ,Col21 = substring(@c_Sparm06,charindex('|',@c_Sparm06)+1,5)
   where Col01 =  @c_Sparm02

   SELECT * FROM #Result WITH (NOLOCK)

   EXIT_SP:       
                               
   END -- procedure     


GO