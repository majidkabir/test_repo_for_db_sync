SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/     
/* Copyright: IDS                                                             */     
/* Purpose: For BarTender Generic Store Procedure                             */     
/*                                                                            */     
/* Modifications log:                                                         */     
/*                                                                            */     
/* Date       Rev  Author     Purposes                                        */     
/* 2013-06-21 1.0  CSCHONG    Created                                         */    
/******************************************************************************/    
      
CREATE PROC [dbo].[isp_BT_Bartender_Result]           
(  @c_SP               NVARCHAR(4000),  
   @c_parm1            NVARCHAR(250),  
   @c_parm2            NVARCHAR(250),  
   @c_parm3            NVARCHAR(250),  
   @c_parm4            NVARCHAR(250),  
   @c_parm5            NVARCHAR(250),  
   @c_parm6            NVARCHAR(250),  
   @c_parm7            NVARCHAR(250),  
   @c_parm8            NVARCHAR(250),  
   @c_parm9            NVARCHAR(250),  
   @c_parm10           NVARCHAR(250)                
)          
AS          
BEGIN          
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET ANSI_WARNINGS OFF          
                  
   DECLARE            
      @c_ExternOrderKey  NVARCHAR(10),  
      @c_OrderLineNo     NVARCHAR(5),  
      @c_SKU             NVARCHAR(20),  
      @n_Qty             INT,  
      @c_PackKey         NVARCHAR(10),  
      @c_UOM             NVARCHAR(10),  
      @c_SQL             NVARCHAR(4000) ,  
      @c_commandSQL      NVARCHAR(4000) ,  
      @c_Parms           NVARCHAR(4000) ,  
      @b_Debug           NVARCHAR(1) ,  
      @nTranCount        INT      
  
  DECLARE @C_SParm1   NVARCHAR(250),  
          @C_SParm2   NVARCHAR(250),  
          @C_SParm3   NVARCHAR(250),  
          @C_SParm4   NVARCHAR(250),  
          @C_SParm5   NVARCHAR(250),  
          @C_SParm6   NVARCHAR(250),  
          @C_SParm7   NVARCHAR(250),  
          @C_SParm8   NVARCHAR(250),  
          @C_SParm9   NVARCHAR(250),  
          @C_SParm10  NVARCHAR(250)  
             
  
  SET @b_Debug=0  
   
     BEGIN TRAN    
  
     CREATE TABLE [#BarTenderResult] (    
      [Col1]  [NVARCHAR] (80) NULL,  
      [Col2]  [NVARCHAR] (80) NULL,  
      [Col3]  [NVARCHAR] (80) NULL,  
      [Col4]  [NVARCHAR] (80) NULL,  
      [Col5]  [NVARCHAR] (80) NULL,  
      [Col6]  [NVARCHAR] (80) NULL,  
      [Col7]  [NVARCHAR] (80) NULL,  
      [Col8]  [NVARCHAR] (80) NULL,  
      [Col9]  [NVARCHAR] (80) NULL,  
      [Col10]  [NVARCHAR] (80) NULL,  
      [Col11]  [NVARCHAR] (80) NULL,  
      [Col12]  [NVARCHAR] (80) NULL,  
      [Col13]  [NVARCHAR] (80) NULL,  
      [Col14]  [NVARCHAR] (80) NULL,  
      [Col15]  [NVARCHAR] (80) NULL,  
      [Col16]  [NVARCHAR] (80) NULL,  
      [Col17]  [NVARCHAR] (80) NULL,  
      [Col18]  [NVARCHAR] (80) NULL,  
      [Col19]  [NVARCHAR] (80) NULL,  
      [Col20]  [NVARCHAR] (80) NULL,  
      [Col21]  [NVARCHAR] (80) NULL,  
      [Col22]  [NVARCHAR] (80) NULL,  
      [Col23]  [NVARCHAR] (80) NULL,  
      [Col24]  [NVARCHAR] (80) NULL,  
      [Col25]  [NVARCHAR] (80) NULL,  
      [Col26]  [NVARCHAR] (80) NULL,  
      [Col27]  [NVARCHAR] (80) NULL,  
      [Col28]  [NVARCHAR] (80) NULL,  
      [Col29]  [NVARCHAR] (80) NULL,  
      [Col30]  [NVARCHAR] (80) NULL,  
      [Col31]  [NVARCHAR] (80) NULL,  
      [Col32]  [NVARCHAR] (80) NULL,  
      [Col33]  [NVARCHAR] (80) NULL,  
      [Col34]  [NVARCHAR] (80) NULL,  
      [Col35]  [NVARCHAR] (80) NULL,  
      [Col36]  [NVARCHAR] (80) NULL,  
      [Col37]  [NVARCHAR] (80) NULL,  
      [Col38]  [NVARCHAR] (80) NULL,  
      [Col39]  [NVARCHAR] (80) NULL,  
      [Col40]  [NVARCHAR] (80) NULL,  
      [Col41]  [NVARCHAR] (80) NULL,  
      [Col42]  [NVARCHAR] (80) NULL,  
    [Col43]  [NVARCHAR] (80) NULL,  
      [Col44]  [NVARCHAR] (80) NULL,  
      [Col45]  [NVARCHAR] (80) NULL,  
      [Col46]  [NVARCHAR] (80) NULL,  
      [Col47]  [NVARCHAR] (80) NULL,  
      [Col48]  [NVARCHAR] (80) NULL,  
      [Col49]  [NVARCHAR] (80) NULL,  
      [Col50]  [NVARCHAR] (80) NULL,  
      [Col51]  [NVARCHAR] (80) NULL,  
      [Col52]  [NVARCHAR] (80) NULL,  
      [Col53]  [NVARCHAR] (80) NULL,  
      [Col54]  [NVARCHAR] (80) NULL,  
      [Col55]  [NVARCHAR] (80) NULL,  
      [Col56]  [NVARCHAR] (80) NULL,  
      [Col57]  [NVARCHAR] (80) NULL,  
      [Col58]  [NVARCHAR] (80) NULL,  
      [Col59]  [NVARCHAR] (80) NULL,  
      [Col60]  [NVARCHAR] (80) NULL,  
     )   
              
     BEGIN TRAN  
  
 --SET @c_SQL = 'INSERT INTO #BarTenderResult' + CHAR(13)+  
  
   SET @c_SQL =N'EXEC ['+ RTRIM(@c_SP) + '] ' + CHAR(13)+          
            '@c_Sparm1        = @c_parm1, ' + CHAR(13)+         
            '@c_Sparm2        = @c_parm2,  ' + CHAR(13) +          
            '@c_Sparm3        = @c_parm3, ' + CHAR(13) +              
            '@c_Sparm4        = @c_parm4, ' + CHAR(13)+          
            '@c_Sparm5        = @c_parm5, ' + CHAR(13)+          
            '@c_Sparm6        = @c_parm6, ' + CHAR(13)+          
            '@c_Sparm7        = @c_parm7, ' + CHAR(13)+          
            '@c_Sparm8        = @c_parm8, ' + CHAR(13)+          
            '@c_Sparm9        = @c_parm9, ' + CHAR(13)+          
            '@c_Sparm10       = @c_parm10 ' + CHAR(13)         
  
         SET @c_Parms =             
            N'@c_parm1       NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm2        NVARCHAR(80),  ' + CHAR(13) +          
            '@c_parm3        NVARCHAR(80), ' + CHAR(13) +              
            '@c_parm4        NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm5        NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm6        NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm7        NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm8        NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm9        NVARCHAR(80), ' + CHAR(13)+          
            '@c_parm10       NVARCHAR(80) ' + CHAR(13)      
                   
         IF @b_debug = 1          
         BEGIN          
            PRINT @c_SQL          
            PRINT @c_Parms          
                      
         END                     
                   
         EXEC sys.sp_executesql @c_SQL, @c_Parms          
                               , @c_parm1          
                               , @c_parm2          
                               , @c_parm3          
                               , @c_parm4          
                               , @c_parm5          
                               , @c_parm6          
                               , @c_parm7                                         
                               , @c_parm8          
                               , @c_parm9          
                               , @c_parm10                                         
                     
                          
         IF @@ERROR = 0          
         BEGIN          
            WHILE @@TRANCOUNT > 0          
               COMMIT TRAN          
                                     
         END          
         ELSE          
         BEGIN          
            ROLLBACK TRAN          
          --  BREAK          
            GOTO EXIT_SP          
         END          
  
  
  --SELECT * FROM #BarTenderResult  
  
  DROP TABLE #BarTenderResult        
EXIT_SP:   
                    
END -- procedure

GO