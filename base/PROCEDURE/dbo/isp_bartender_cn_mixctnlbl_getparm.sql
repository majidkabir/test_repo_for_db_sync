SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_CN_mixctnlbl_GetParm                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-05-24 1.0  CSCHONG    Created (WMS-4975)                              */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_CN_mixctnlbl_GetParm]                      
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
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                                     
                              
   DECLARE                  
      @c_ReceiptKey      NVARCHAR(10),                    
      @c_RDUDF01         NVARCHAR(30),    
      @c_storerkey       NVARCHAR(20),                 
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_ExecArguments   NVARCHAR(4000),
      @c_SQLInsert       NVARCHAR(4000),
      @c_parm01          NVARCHAR(250),
      @c_parm02          NVARCHAR(250),
      @c_parm03          NVARCHAR(250),
      @n_ttlctn          INT,
      @n_Skuctn          INT,
      @n_Cartonno        INT,
      @n_lineno          INT,
      @n_qty             INT 
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @n_cntsku           INT,
           @c_mode             NVARCHAR(1),
           @c_sku              NVARCHAR(20),
           @c_getOrderkey      NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_key01            NVARCHAR(50),
           @n_lineCtn          INT,
           @n_LineStart        INT,
           @c_getparm02        NVARCHAR(80),
           @c_getparm03        NVARCHAR(80),
           @c_getparm04        NVARCHAR(80),
           @c_getparm01        NVARCHAR(80),
           @c_getparm07        NVARCHAR(80),
           @n_getparm10        INT
                        
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    
    CREATE TABLE #TEMPRESULT  (
      ROWID    INT IDENTITY(1,1),
     PARM01       NVARCHAR(80),  
     PARM02       NVARCHAR(80),  
     PARM03       NVARCHAR(80),  
     PARM04       NVARCHAR(80),  
     PARM05       NVARCHAR(80),  
     PARM06       NVARCHAR(80)
     
    )
    
      CREATE TABLE #TEMPRECUDF (
      RowID          INT IDENTITY (1,1) NOT NULL ,
      storerkey      NVARCHAR(20),
      RECEIPTKEY     NVARCHAR(20) ,
      RDUDF01        NVARCHAR(30)  )
   
      INSERT INTO #TEMPRECUDF (storerkey,RECEIPTKEY,RDUDF01)
      SELECT RD.storerkey,RD.receiptkey,RD.userdefine01
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      where storerkey =@parm01
      and receiptkey=@parm02
      and isnull(userdefine01,'') <> ''
      group by RD.storerkey,receiptkey,userdefine01
      having count (distinct sku) > 1
      order by RD.userdefine01 desc
          
       
        SET @n_lineno = 1
        
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT storerkey,receiptkey,RDUDF01 
   FROM   #TEMPRECUDF     
   WHERE storerkey =@parm01
   AND receiptkey=@parm02
   ORDER BY RDUDF01
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_storerkey,@c_receiptkey,@c_RDUDF01
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
      
   SET @n_ttlctn = 0

   SELECT @n_ttlctn = COUNT(1)--,@n_qty = (QtyExpected)
   FROM RECEIPTDETAIL WITH (NOLOCK)
   WHERE storerkey =@c_storerkey
   AND receiptkey=@c_receiptkey
   and Userdefine01 = @c_RDUDF01
  -- GROUP BY QtyExpected

   IF NOT EXISTS (SELECT 1 FROM #TEMPRESULT
                  WHERE PARM02 = @c_RDUDF01)
   BEGIN

      INSERT INTO #TEMPRESULT(
                                PARM01,   
                                PARM02,   
                                PARM03,   
                                PARM04,   
                                PARM05,   
                                PARM06
                              )

      SELECT RD.receiptkey,rd.UserDefine01,rd.Sku,QtyExpected,
            ROW_NUMBER() OVER(PARTITION BY RD.UserDefine01 ORDER BY RD.sku),convert(nvarchar(10),@n_ttlctn)
      FROM RECEIPTDETAIL RD WITH(NOLOCK)
      WHERE RD.storerkey =@c_storerkey
      AND RD.receiptkey=@c_receiptkey
      and RD.UserDefine01 = @c_RDUDF01
      GROUP BY RD.receiptkey,rd.UserDefine01,rd.Sku,QtyExpected
   END
   
      
   FETCH NEXT FROM CUR_RESULT INTO @c_storerkey,@c_receiptkey,@c_RDUDF01
   END        
  
  --SELECT * FROM #TEMPRESULT
  --ORDER BY ROWID
                 
        SELECT PARM1=TR.PARM01,PARM2=TR.PARM02,PARM3=TR.PARM03,PARM4=TR.PARM04,PARM5=TR.PARM05,
                     PARM6= TR.PARM06,PARM7='',PARM8='',PARM9='',PARM10='',Key1='receiptkey',Key2='',Key3='',Key4='',Key5=''
        FROM #TEMPRESULT TR WITH (NOLOCK)  
        WHERE TR.parm01 >= @parm02      
        ORDER BY TR.ROWID--TSR.PARM03,CONVERT(INT,TSR.PARM10)
    
               
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  

                                  
   END -- procedure   



GO