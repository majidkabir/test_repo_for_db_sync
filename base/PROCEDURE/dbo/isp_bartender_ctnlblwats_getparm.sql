SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                       
/* Copyright: IDS                                                             */                       
/* Purpose: isp_Bartender_CTNLBLWATS_GetParm                                  */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date         Rev  Author     Purposes                                      */     
/* 30-Sep-2021  1.0  CSCHONG    Devops scripts combine                        */     
/* 30-Sep-2021  1.1  CSCHONG    Created (WMS-18030)                           */                                           
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_Bartender_CTNLBLWATS_GetParm]                            
(  @parm01            NVARCHAR(250),                    
   @parm02            NVARCHAR(250),                    
   @parm03            NVARCHAR(250),                    
   @parm04            NVARCHAR(250),                    
   @parm05            NVARCHAR(250),                    
   @parm06            NVARCHAR(250),                    
   @parm07            NVARCHAR(250),                    
   @parm08            NVARCHAR(250),                    
   @parm09            NVARCHAR(250),                    
   @parm10            NVARCHAR(250),              
   @b_debug           INT = 0                               
)                            
AS                            
BEGIN                            
   SET NOCOUNT ON                       
   SET ANSI_NULLS OFF                      
   SET QUOTED_IDENTIFIER OFF                       
   SET CONCAT_NULL_YIELDS_NULL OFF                      
                                    
   DECLARE                        
      @c_ReceiptKey        NVARCHAR(10),                          
      @c_ExternOrderKey  NVARCHAR(10),                    
      @c_Deliverydate    DATETIME,                    
      @n_intFlag         INT,           
      @n_CntRec          INT,          
      @c_SQL             NVARCHAR(4000),   
      @c_SQLInsert       NVARCHAR(4000),               
      @c_SQLSORT         NVARCHAR(4000),              
      @c_SQLJOIN         NVARCHAR(4000),      
      @c_condition1      NVARCHAR(150) ,      
      @c_condition2      NVARCHAR(150),      
      @c_SQLGroup        NVARCHAR(4000),      
      @c_SQLOrdBy        NVARCHAR(150),  
      @c_storerkey       NVARCHAR(20),  
      @n_Maxcopy         INT,  
      @n_NoCopy          INT      
            
          
  DECLARE  @d_Trace_StartTime   DATETIME,         
           @d_Trace_EndTime    DATETIME,        
           @c_Trace_ModuleName NVARCHAR(20),         
           @d_Trace_Step1      DATETIME,         
           @c_Trace_Step1      NVARCHAR(20),        
           @c_UserName         NVARCHAR(20),      
           @c_ExecStatements   NVARCHAR(4000),          
           @c_ExecArguments    NVARCHAR(4000)              
        
   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
              
    -- SET RowNo = 0                   
    SET @c_SQL = ''         
    SET @c_SQLJOIN = ''              
    SET @c_condition1 = ''      
    SET @c_condition2= ''      
    SET @c_SQLOrdBy = ''      
    SET @c_SQLGroup = ''      
    SET @c_ExecStatements = ''      
    SET @c_ExecArguments = ''   
    SET @c_storerkey = ''   
    SET @n_NoCopy = 0  
     
    CREATE TABLE #TEMPRESULT  (  
     PARM01       NVARCHAR(80),    
     PARM02       NVARCHAR(80),    
     PARM03       NVARCHAR(80),    
     PARM04       NVARCHAR(80),    
     PARM05       NVARCHAR(80),    
     PARM06       NVARCHAR(80),    
     PARM07       NVARCHAR(80),    
     PARM08       NVARCHAR(80),    
     PARM09       NVARCHAR(80),    
     PARM10       NVARCHAR(80),    
     Key01        NVARCHAR(80),  
     Key02        NVARCHAR(80),  
     Key03        NVARCHAR(80),  
     Key04        NVARCHAR(80),  
     Key05        NVARCHAR(80)  
       
    )  
  IF ISNULL(@parm01,'') <> '' AND (ISNULL(@parm02,'') <> '' OR ISNULL(@parm03,'') <> '' OR ISNULL(@parm04,'') <> '')
  BEGIN   
    
    IF OBJECT_ID('tempdb..#CTNLBLWATSPD') IS NOT NULL
    DROP TABLE #CTNLBLWATSPD

    SELECT orderkey AS orderkey,
          orderlinenumber AS orderlinenum,
          sku AS sku, 
          storerkey AS storerkey,
          lot AS lot, 
          sum(qty) AS qty 
     INTO #CTNLBLWATSPD
     FROM pickdetail WITH (nolock) 
     WHERE orderkey = @parm02
     GROUP BY orderkey,orderlinenumber,Storerkey,lot,sku


    IF OBJECT_ID('tempdb..#CTNLBLWATSCS') IS NOT NULL
    DROP TABLE #CTNLBLWATSCS

       SELECT 
       Storerkey = CS.StorerKey,  --Storer
       Idssku = CS.SKU,  --Idssku
       Wasonssku = CS.ConsigneeSKU,  --Wasonssku
       CSUDF03 = CS.udf03 -- UDF03
       INTO #CTNLBLWATSCS
       FROM ConsigneeSKU CS WITH (NOLOCK)
       JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME='Consignee' AND CL.Storerkey=@parm01 AND CL.Code=CS.ConsigneeKey
     
   
    SET @c_SQLInsert = ''  
    SET @c_SQLInsert ='INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' + CHAR(13) +  
                     ' Key01,Key02,Key03,Key04,Key05)'  
        
       
   IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.storerkey = @Parm01 )   
   BEGIN  
     IF ISNULL(@Parm07,'') <> ''  
     BEGIN  
  
      SET @n_NoCopy = CAST(@Parm07 as int)  
      SET @n_Maxcopy = 100  
       
      --SELECT @c_storerkey = OH.Storerkey  
      --FROM ORDERS OH WITH (NOLOCK)  
      --WHERE OH.OrderKey = @Parm02  
  
      SELECT @n_Maxcopy = CAST(C.short as int)   
      FROM CODELKUP C WITH (NOLOCK)  
      WHERE LISTNAME = 'MaxNoCopy'  
      AND Code = 'NoOfCopy'  
      AND Storerkey =  @Parm01
      
      IF @n_maxcopy = 0  
      BEGIN  
        SET @n_Maxcopy = 100  
      END  
  
      IF @n_NoCopy > @n_Maxcopy  
      BEGIN  
         GOTO EXIT_SP  
      END  
    END 

        IF @b_debug = 1
        BEGIN
          SELECT @parm07 '@parm07',@n_NoCopy '@n_NoCopy'
        END   
 
   -- print '1'  
       SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=OH.Storerkey,PARM2=OH.orderkey,PARM3= TPD.sku ,PARM4= LOTT.lottable02,PARM5=TCS.Wasonssku,PARM6='''','+ 
         ' PARM7= CASE WHEN @n_NoCopy > 0 THEN @n_NoCopy ELSE CEILING(sum(TPD.qty) / P.casecnt) END , '+   
         ' PARM8='''',PARM9='''',PARM10=CASE WHEN OH.Storerkey = ''HHT'' AND ISDATE(LOTT.lottable03) = 1 THEN Convert(Nvarchar(10),CAST(LOTT.lottable03 as datetime),111) ELSE CONVERT(NVARCHAR(10),LOTT.lottable04,111) END, ' +
         ' Key1='''',Key2='''',Key3='''',' +      
         ' Key4='''','+      
         ' Key5= '''' '  +        
         ' FROM ORDERS OH WITH (NOLOCK) ' + 
         ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey ' +
         ' JOIN PICKDETAIL TPD ON TPD.Orderkey = OD.Orderkey AND TPD.orderlinenumber = OD.orderlinenumber AND TPD.Sku = OD.SKU AND TPD.Storerkey = OD.Storerkey ' +
         ' JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = TPD.lot AND LOTT.Storerkey = TPD.Storerkey AND LOTT.Sku = TPD.Sku ' +
         ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = TPD.Storerkey AND S.SKU = TPD.Sku ' +
         ' JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.packkey ' +
         ' JOIN #CTNLBLWATSCS TCS ON TCS.storerkey = S.storerkey AND TCS.Idssku = S.sku ' +
         ' WHERE OH.Storerkey = @parm01 AND OH.Orderkey = CASE WHEN ISNULL(@parm02,'''') <> '''' THEN @Parm02 ELSE OH.Orderkey END '  +
         ' AND OH.Userdefine09 = CASE WHEN ISNULL(@parm03,'''') <> '''' THEN @parm03 ELSE OH.userdefine09 END '+
         ' AND OH.Externorderkey = CASE WHEN ISNULL(@parm04,'''') <> ''''  THEN @parm04 ELSE OH.Externorderkey END ' +
         ' AND TPD.sku = CASE WHEN ISNULL(@parm05,'''') <> '''' THEN @parm05 ELSE TPD.sku END ' +
         ' AND LOTT.lottable02 = CASE WHEN ISNULL(@parm06,'''') <> '''' THEN @parm06 ELSE LOTT.lottable02 END ' +
         ' GROUP BY OH.Storerkey,OH.orderkey,TPD.sku,LOTT.lottable02,TCS.Wasonssku,P.casecnt,' +
         ' CASE WHEN OH.Storerkey = ''HHT'' AND ISDATE(LOTT.lottable03) = 1 THEN Convert(Nvarchar(10),CAST(LOTT.lottable03 as datetime),111) ELSE CONVERT(NVARCHAR(10),LOTT.lottable04,111) END' + CHAR(13) +
         ' ORDER BY OH.orderkey, TPD.sku,' + 
         ' CASE WHEN OH.Storerkey = ''HHT'' AND ISDATE(LOTT.lottable03) = 1 THEN Convert(Nvarchar(10),CAST(LOTT.lottable03 as datetime),111) ELSE CONVERT(NVARCHAR(10),LOTT.lottable04,111) END,LOTT.lottable02' 

   END  
             
        SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN    
        --PRINT  @c_SQLJOIN  
        IF @b_debug = 1
        BEGIN
          SELECT @c_SQL
        END         
          
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'          
                          + ', @parm02           NVARCHAR(80) '          
                          + ', @parm03           NVARCHAR(80)'         
                          + ', @parm04           NVARCHAR(80)'  
                          + ', @parm05           NVARCHAR(80)'  
                          + ', @parm06           NVARCHAR(80)'   
                          + ', @parm07           NVARCHAR(80)'  
                          + ', @n_NoCopy         INT'
                                    
   EXEC sp_ExecuteSql     @c_SQL           
                        , @c_ExecArguments          
                        , @parm01          
                        , @parm02         
                        , @parm03    
                        , @parm04          
                        , @parm05         
                        , @parm06
                        , @parm07
                        , @n_NoCopy
                    
  
     SELECT * FROM #TEMPRESULT  
     ORDER BY PARM02,PARM03,PARM10,PARM04

 END                     
                  
   EXIT_SP:          
        
      SET @d_Trace_EndTime = GETDATE()        
      SET @c_UserName = SUSER_SNAME()        
                                        
   END -- procedure   

GO