SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_CTNLABEL02_GetParm                                  */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2019-07-26 1.0  CSCHONG    Created (WMS-9965&WMS-9990)                     */   
/* 2019-09-05 1.1  CSCHONG    WMS-10384 revised print logic (CS01)            */               
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_CTNLABEL02_GetParm]                        
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
      @c_ReceiptKey      NVARCHAR(10),                      
      @c_ExternOrderKey  NVARCHAR(10),                
      @c_Deliverydate    DATETIME,                
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(MAX),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_condition1      NVARCHAR(150) ,  
      @c_condition2      NVARCHAR(150),  
      @c_SQLGroup        NVARCHAR(4000),  
      @c_SQLOrdBy        NVARCHAR(150),  
      @c_ExecArguments   NVARCHAR(4000),
      @c_SQLINSERT       NVARCHAR(4000),
      @c_SQLSELECT       NVARCHAR(4000),
      @d_lottable04      DATETIME,        --CS01
      @c_lottable04      NVARCHAR(10)        --CS01
        
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20)  

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_ExtOrderkey     NVARCHAR(50)
         , @c_SKU             NVARCHAR(20)
         , @c_Sdescr          NVARCHAR(120)
         , @n_pqty            INT
         , @c_casecnt         FLOAT
         , @c_FullCtn         INT
         , @n_looseqty        INT
         , @n_Ctn             INT
         , @n_startcnt        INT
         , @n_Packqty         INT
         , @c_Storerkey       NVARCHAR(20)
         , @c_ctndescr        NVARCHAR(50)
         , @n_ttlctn          INT            

    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
   SET @c_ctndescr = ''
   SET @n_startcnt = 1


   CREATE Table #TempPackListBAR(
                 OrderKey        NVARCHAR(10) NULL 
            , SKU                NVARCHAR(20) NULL
            , SDESCR             NVARCHAR(120) NULL  
            , PackQty            INT 
            , CtnNo              INT  
            , ExternOrderkey     NVARCHAR(50) NULL 
            , CtnDescr           NVARCHAR(50) NULL
            , Lottable04         NVARCHAR(10) NULL  --CS01
            ) 
          
    -- SET RowNo = 0           
   
   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM PICKDETAIL PD WITH (nolock)
   WHERE PD.Orderkey = @parm01    
  /*CS01 START*/
  IF ISNULL(@parm02,'') = '' 
  BEGIN   
   SET @c_sql = N'DECLARE CUR_RESULT CURSOR FAST_FORWARD READ_ONLY FOR ' 
   + CHAR(13) +  'select DISTINCT ORD.ExternOrderkey,PD.SKU,S.descr,SUM(PD.QTY),P.casecnt,FLOOR(SUM(PD.qty)/P.casecnt) as ctn'
   + CHAR(13) +  ',(SUM(PD.QTY)%cast(P.casecnt as int)) as looseqty,'''' as lottable04 '
   + CHAR(13) +  ' FROM PICKDETAIL PD WITH (NOLOCK) '
   + CHAR(13) +  ' JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.orderkey '
   + CHAR(13) +  ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU '
   + CHAR(13) +  ' JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey '
   + CHAR(13) +  ' WHERE PD.Storerkey = @c_Storerkey '
   + CHAR(13) +  ' AND PD.Orderkey = @parm01 '
   + CHAR(13) +  ' GROUP BY ORD.ExternOrderkey,PD.SKU,S.descr,P.casecnt '
   + CHAR(13) +  ' ORDER BY PD.SKU  '
    
  END
  ELSE IF ISNULL(@parm02,'') = 'LOT04' 
  BEGIN
   SET @c_sql = N' DECLARE CUR_RESULT CURSOR FAST_FORWARD READ_ONLY FOR ' 
   + CHAR(13) +  ' select DISTINCT ORD.ExternOrderkey,PD.SKU,S.descr,SUM(PD.QTY),P.casecnt,FLOOR(SUM(PD.qty)/P.casecnt) as ctn'
   + CHAR(13) +  ',(SUM(PD.QTY)%cast(P.casecnt as int)) as looseqty,LOTT.Lottable04 as lottable04 '
   + CHAR(13) +  ' FROM PICKDETAIL PD WITH (NOLOCK) '
   + CHAR(13) +  ' JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.orderkey '
   + CHAR(13) +  ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU '
   + CHAR(13) +  ' JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey '
   + CHAR(13) +  ' JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PD.lot and LOTT.SKU = PD.SKU '
   + CHAR(13) +  '                                      AND LOTT.Storerkey = PD.Storerkey '
   + CHAR(13) +  ' WHERE PD.Storerkey = @c_Storerkey '
   + CHAR(13) +  ' AND PD.Orderkey = @parm01 '
   + CHAR(13) +  ' GROUP BY ORD.ExternOrderkey,PD.SKU,S.descr,P.casecnt,LOTT.Lottable04 '
   + CHAR(13) +  ' ORDER BY PD.SKU,LOTT.Lottable04  '
  END 
    
  
   SET @c_ExecArguments = N'@c_Storerkey      NVARCHAR(80)'    
                       + ', @parm01           NVARCHAR(80) '    

                                          
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Storerkey    
                        , @parm01
                    
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_pqty,@c_casecnt,@c_FullCtn,@n_looseqty,@d_lottable04   --CS01
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 

   SET @c_lottable04 = ''
   SET @c_lottable04 = CONVERT(NVARCHAR(10),@d_lottable04,101)

   SET @n_Packqty = 1

     IF @n_startcnt = 1
     BEGIN
      IF @c_FullCtn = 0 
      BEGIN
        IF @n_looseqty <> 0 
        BEGIN
          SET @n_Packqty = @n_looseqty
          SET @c_ctndescr = 'Loose'
        END
        ELSE
        BEGIN
          SET @n_Packqty = @c_casecnt
        SET @c_ctndescr = 'Loose'
        END
        INSERT INTO #TempPackListBAR (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo,CtnDescr )
          VALUES(@parm01,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt,@c_ctndescr)

          SET @n_startcnt = @n_startcnt + 1
        

      END --@c_FullCtn = 0
      ELSE
      BEGIN
         WHILE @c_FullCtn  > 0 
         BEGIN
           SET @n_Packqty = @c_casecnt
           SET @c_ctndescr = 'Full'

           INSERT INTO #TempPackListBAR (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo,CtnDescr,Lottable04 )  --CS01
           VALUES(@parm01,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt,@c_ctndescr,@c_lottable04)      --CS01

          SET @n_startcnt = @n_startcnt + 1
          SET @c_FullCtn = @c_FullCtn - 1
         END 
         
         IF @c_FullCtn = 0 AND @n_looseqty <> 0
         BEGIN
            SET @n_Packqty = @n_looseqty
         SET @c_ctndescr = 'Loose'
            INSERT INTO #TempPackListBAR (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo,CtnDescr,Lottable04 )  --CS01
            VALUES(@parm01,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt,@c_ctndescr,@c_lottable04)     --CS01

            SET @n_startcnt = @n_startcnt + 1
         END 
      END--@c_FullCtn <> 0
     END  --@n_startcnt = 1
     ELSE
     BEGIN

     IF @c_FullCtn = 0 
      BEGIN
        IF @n_looseqty <> 0 
        BEGIN
          SET @n_Packqty = @n_looseqty
        SET @c_ctndescr = 'Loose'
        END
        ELSE
        BEGIN
          SET @n_Packqty = @c_casecnt
        SET @c_ctndescr = 'Loose'
        END
        INSERT INTO #TempPackListBAR (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo,CtnDescr,Lottable04 )   --CS01
        VALUES(@parm01,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt,@c_ctndescr,@c_lottable04)   --CS01

          SET @n_startcnt = @n_startcnt + 1

      END --@c_FullCtn = 0
      ELSE
      BEGIN
         WHILE @c_FullCtn  > 0 
         BEGIN
           SET @n_Packqty = @c_casecnt
         SET @c_ctndescr = 'Full'

           INSERT INTO #TempPackListBAR (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo,CtnDescr,Lottable04  )   --CS01
           VALUES(@parm01,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt,@c_ctndescr,@c_lottable04)     --CS01

           SET @n_startcnt = @n_startcnt + 1
           SET @c_FullCtn = @c_FullCtn - 1
         END 
         
         IF @c_FullCtn = 0 AND @n_looseqty <> 0
         BEGIN
            SET @n_Packqty = @n_looseqty
         SET @c_ctndescr = 'Loose'
            INSERT INTO #TempPackListBAR (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo,CtnDescr,Lottable04  )  --CS01
            VALUES(@parm01,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt,@c_ctndescr,@c_lottable04)   --CS01

            SET @n_startcnt = @n_startcnt + 1
         END 
      END--@c_FullCtn <> 0
     END

   FETCH NEXT FROM CUR_RESULT INTO @c_ExtOrderkey, @c_SKU,@c_Sdescr,@n_pqty,@c_casecnt,@c_FullCtn,@n_looseqty ,@d_lottable04   --CS01 
   END 
   CLOSE  CUR_RESULT
   DEALLOCATE CUR_RESULT

   SET @n_ttlctn = 1

   SELECT @n_ttlctn = MAX(ctnno)
   FROM #TempPackListBAR
    WHERE OrderKey = @parm01
    
   SELECT DISTINCT PARM1=ctnno, PARM2=CAST(@n_ttlctn as nvarchar(10)),PARM3=CtnDescr,
                   PARM4=OrderKey,PARM5=ExternOrderkey,PARM6=SKU,PARM7='',PARM8='',PARM9='',PARM10=Lottable04
       ,Key1='ctn',Key2='',Key3='',Key4='',Key5='' 
       FROM #TempPackListBAR WHERE OrderKey = @parm01
       order by ctnno
   
    EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()  
     
     DROP TABLE #TempPackListBAR 
  
                                    
   END -- procedure  
   

GO