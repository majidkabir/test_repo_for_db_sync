SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_CTNLABEL01_GetParm                                  */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2018-10-29 1.0  CSCHONG    Created (WMS-6564)                              */                   
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_CTNLABEL01_GetParm]                        
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
      @c_ReceiptKey        NVARCHAR(10),                      
      @c_ExternOrderKey  NVARCHAR(10),                
      @c_Deliverydate    DATETIME,                
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
      @c_SQLINSERT       NVARCHAR(4000),
      @c_SQLSELECT       NVARCHAR(4000)
        
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @n_cntsku           INT,  
           @c_mode             NVARCHAR(1),  
           @c_sku              NVARCHAR(20),  
           @c_getUCCno         NVARCHAR(20),  
           @c_getUdef09        NVARCHAR(30),
           @n_totalPage        INT  ,
           @c_PageInput        NVARCHAR(1),
           @n_PageCnt          INT,
           @c_orderkey         NVARCHAR(20),
           @n_CtnRec           INT,
           @n_LastPage         INT
            

    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    


    CREATE TABLE [#TEMPORDER] (                   
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                      
      [Orderkey]    [NVARCHAR] (20)  NULL,
     [Pageno]      INT NULL DEFAULT(0) )   
          
    -- SET RowNo = 0               
    SET @c_SQL = ''     
    SET @c_mode = '0'     
    SET @c_getUCCno = ''  
    SET @c_getUdef09 = ''    
    SET @c_SQLJOIN = ''          
    SET @c_condition1 = ''  
    SET @c_condition2= ''  
    SET @c_SQLOrdBy = ''  
    SET @c_SQLGroup = ''  
    SET @c_PageInput = 'N'
    SET @n_LastPage = 0
      
   SET @c_SQLINSERT = ' INSERT INTO #TEMPORDER (Orderkey) '

   IF EXISTS (SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
              WHERE WAVEKEY = @parm01)
   BEGIN
    
   SET @c_SQLSELECT = ' SELECT DISTINCT WD.Orderkey ' +
                      ' FROM WAVEDETAIL WD WITH (NOLOCK) ' +
                      ' JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = WD.Orderkey' +
                      ' WHERE WD.Wavekey = @parm01 ' +
                      ' AND ORD.Status =''3'' AND ORD.Stop = ''TW10'' ' +
                      ' Order By WD.Orderkey '
   END
   ELSE IF EXISTS (SELECT 1 FROM pickheader WITH (NOLOCK)
                   WHERE Pickheaderkey = @parm02)
  BEGIN
    SET @c_SQLSELECT = ' SELECT DISTINCT PH.Orderkey ' +
                       ' FROM pickheader PH WITH (NOLOCK) ' +
                       ' WHERE PH.Pickheaderkey = @parm02 ' +
                       ' Order By PH.Orderkey '

  END
  
  IF ISNULL(@parm03,'') <> '' AND ISNULL(@parm04,'') <> ''
  BEGIN

      IF EXISTS (SELECT 1 FROM ORDERS OH (NOLOCK)
                WHERE OH.Orderkey = @parm03) 
                AND EXISTS (SELECT 1 FROM ORDERS OH (NOLOCK)
                WHERE OH.Orderkey = @parm04)
      BEGIN
      
      SET @c_SQLSELECT = ' SELECT DISTINCT OH.Orderkey ' +
                        ' FROM Orders OH WITH (NOLOCK) ' +
                        ' WHERE OH.Orderkey between @parm03 AND @parm04 ' +
                        ' Order By OH.Orderkey '
      
      END

  END

  SET @c_SQLJOIN  = @c_SQLINSERT + CHAR(13) + @c_SQLSELECT

   SET @c_ExecArguments = N'@parm01          NVARCHAR(80), '   
                        + ' @parm02          NVARCHAR(80),'  
                        + ' @parm03          NVARCHAR(80),' 
                        + ' @parm04          NVARCHAR(80)' 
       
    EXEC sp_executesql   @c_SQLJOIN    
                       , @c_ExecArguments      
                       , @parm01   
                       , @parm02  
                       , @parm03   
                       , @parm04 
                       
                    
      
   SET @c_ExecArguments = '' 
   SET @c_SQLJOIN = '' 
   SET @n_totalPage = 0

  
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Orderkey   
   FROM   #TEMPORDER ORD   
   ORDER BY Orderkey
  
   OPEN CUR_RowNoLoop   
     
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Orderkey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

   --SET @n_totalPage = 0


      
  IF ISNULL(@parm05,'') <> '' AND ISNULL(@parm06,'') <> ''
  BEGIN
    SET @n_LastPage = 0
    SET @n_totalPage = 0
    
    SET @c_PageInput = 'Y'
    SET @n_LastPage = CAST(@parm06 as INT)
    SET @n_totalPage = (CAST(@parm06 as INT)-CAST(@parm05 as INT)) + 1

  END

   IF @c_PageInput = 'N'
   BEGIN
     SET @n_totalPage = 0
     SET @n_LastPage = 0

     SELECT @n_totalPage = sum(CASE WHEN ISNULL(CEILING(od.qtyallocated/p.casecnt),'0') = 0 then 1 ELSE CEILING(od.qtyallocated/p.casecnt) END) 
     FROM orders oh (nolock)
     JOIN orderdetail od (nolock) on od.orderkey = oh.orderkey
     JOIN sku s (nolock) on s.storerkey = od.storerkey and s.sku=od.sku
     JOIN pack p (nolock) on p.packkey = s.packkey
     WHERE oh.orderkey = @c_Orderkey
     AND oh.status='3' 
     AND oh.stop='TW10'
     GROUP BY oh.orderkey
     ORDER BY oh.orderkey

     SET @n_LastPage = @n_totalPage
   END

   
 
   WHILE @n_totalPage >= 1
   BEGIN
    
         SET @n_CtnRec = 0

         SELECT @n_CtnRec = COUNT(1)
         FROM #TEMPORDER
         WHERE Orderkey = @c_Orderkey and pageno = 0

         --select @c_Orderkey '@c_Orderkey',@n_totalPage '@n_totalPage',@n_CtnRec '@n_CtnRec'

         IF @n_CtnRec = 1
         BEGIN
          UPDATE #TEMPORDER
          SET Pageno = @n_LastPage
         where orderkey = @c_Orderkey
         END
         ELSE
         BEGIN
         IF NOT EXISTS (SELECT 1 FROM  #TEMPORDER
                        WHERE orderkey=@c_Orderkey AND pageno = @n_totalPage)
             BEGIN
             INSERT INTO #TEMPORDER (orderkey,pageno)
             VALUES (@c_Orderkey,@n_LastPage)
             END

         END
   
      SET @n_totalPage = @n_totalPage - 1
      SET @n_LastPage = @n_LastPage - 1 

   END

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Orderkey  
   END
   CLOSE CUR_RowNoLoop                  
   DEALLOCATE CUR_RowNoLoop  


    SELECT PARM1=Orderkey,PARM2=pageno,PARM3='',PARM4='',PARM5='',
    PARM6='',PARM7='',PARM8='',PARM9='',PARM10='',Key1='orderkey',Key2='pageno',Key3='',Key4='',Key5=''
    FROM #TEMPORDER 
    Order by Orderkey,Pageno
   
    EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()  
     
     DROP TABLE #TEMPORDER 
  
                                    
   END -- procedure  
   

GO