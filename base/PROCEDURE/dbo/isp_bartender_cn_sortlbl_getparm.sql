SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_CN_Sortlbl_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-04-06 1.0  CSCHONG    Created (WMS-4440)                              */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_CN_Sortlbl_GetParm]                      
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
      @c_OrderKey        NVARCHAR(10),                    
      @c_PrintMbol       NVARCHAR(1),    
      @c_printbyOrder    NVARCHAR(1),          
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
      @c_SQLInsert       NVARCHAR(4000),
      @c_parm01          NVARCHAR(250),
      @c_parm02          NVARCHAR(250),
      @c_parm03          NVARCHAR(250),
      @n_ttlctn          INT,
      @n_Skuctn          INT,
      @n_Cartonno        INT,
      @n_ctnrec          INT,
      @n_lineno          INT,
      @n_recid           INT 
      
    
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
           @c_getparm06        NVARCHAR(80), --vince
           @c_getparm07        NVARCHAR(80),
           @n_getparm10        INT
                        
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    
    CREATE TABLE #TEMPSLRESULT  (
     ROWID    INT IDENTITY(1,1),
     PARM01       NVARCHAR(80),  
     PARM02       NVARCHAR(80), 
     PARM03       NVARCHAR(80),  
     PARM04       NVARCHAR(80),  
     PARM05       NVARCHAR(80),  
     PARM06       NVARCHAR(80),  
     PARM07       NVARCHAR(80),
     PARM08       NVARCHAR(80),
     PARM09       NVARCHAR(5),
     PARM10       INT DEFAULT(1)
     
    )
    
     CREATE TABLE #TEMPRESULTOP  (
     ROWID    INT IDENTITY(1,1),
     PARM01       NVARCHAR(80),  
     PARM02       NVARCHAR(80),  
     PARM03       NVARCHAR(80),  
     PARM04       NVARCHAR(80),  
     PARM05       NVARCHAR(80),  
     PARM06       NVARCHAR(80),  
     PARM07       NVARCHAR(80),
     PARM08       NVARCHAR(80),
     PARM09       NVARCHAR(5),
     PARM10       INT DEFAULT(1)
     
    )
    
   
     INSERT INTO #TEMPSLRESULT
     (
      -- ROWID -- this column value is auto-generated
      PARM01,
      PARM02,
      PARM03,
      PARM04,
      PARM05,
      PARM06,
      PARM07,PARM08,PARM09,parm10
     )
     SELECT  
         FLOOR(RP.Qty/P.CaseCnt) CTNQTY,  --vince
         @parm04 BatchNo,RP.fromLoc LOC ,
         SUBSTRING(S.Sku, 1, 6) + '-' + SUBSTRING(S.Sku, 7, 2) + '-' + S.SIZE SKU_SIZE,
         P.CaseCnt ,RP.ToLoc,
         '6' uom,'0' AS parm08,'O' AS parm09,1 AS parm10
         FROM  ORDERdetail OD WITH (NOLOCK)
         JOIN SKU S WITH (NOLOCK) ON OD.sku=S.sku
           AND OD.Storerkey = S.StorerKey
         JOIN PACK P WITH (NOLOCK) ON S.PACKKey = P.PackKey
         JOIN REPLENISHMENT RP WITH (NOLOCK) ON OD.Sku = RP.Sku 
              AND S.StorerKey = RP.Storerkey
         WHERE  OD.StorerKey = @parm01
                 AND RP.Confirmed = 'N'
           AND RP.RepLENNo <> 'Y'
              AND OD.LoadKey BETWEEN @parm02 AND  @parm03   
   GROUP BY 
         SUBSTRING(S.Sku, 1, 6) + '-' + SUBSTRING(S.Sku, 7, 2) + '-' + S.SIZE  ,
         RP.Qty/P.CaseCnt,
         P.CaseCnt ,
         RP.fromLoc ,
         P.PackKey ,
         RP.ToLoc
   UNION ALL
   SELECT  CTNQTY,BatchNo,loc,SKU_SIZE,casecnt,toloc,uom,parm08,parm09,parm10 FROM (
     SELECT  
         SUM(PD.Qty)/P.CaseCnt CTNQTY,@parm04 BatchNo,PD.LOC,
         SUBSTRING(PD.Sku, 1, 6) + '-' + SUBSTRING(PD.Sku, 7, 2) + '-' + S.SIZE SKU_SIZE,
         P.CaseCnt ,OD.LOADKEY toloc,
         PD.uom,'0' AS parm08,'O' AS parm09,1 AS parm10
   FROM  ORDERdetail OD WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON  PD.OrderKey = OD.OrderKey AND OD.Sku=PD.Sku
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.Sku
           AND PD.Storerkey = S.StorerKey
         JOIN PACK p WITH (NOLOCK) ON S.PACKKey = P.PackKey
         JOIN LOC L WITH (NOLOCK) ON PD.Loc = L.Loc
   WHERE  ( (OD.StorerKey = @parm01
              AND L.LocationType <> 'PICK'
              AND OD.LoadKey BETWEEN @parm02 AND  @parm03
              AND PD.UOM = '2'
             )
            )
   GROUP BY 
         SUBSTRING(PD.Sku, 1, 6) + '-' + SUBSTRING(PD.Sku, 7, 2) + '-' + S.SIZE  ,
         OD.LoadKey ,
         P.CaseCnt ,
         PD.Loc ,
         PD.uom) b
        ORDER BY loc,toloc
        
        
        SET @n_ttlctn = 0
        SET @n_lineno = 1
        
     DELETE FROM  #TEMPSLRESULT WHERE PARM01=0--vince
     --SELECT @n_ttlctn = SUM(convert(int,parm01))
       -- FROM #TEMPSLRESULT

     --vince
     IF  ISNULL(@parm07,'')=0
     BEGIN
        SELECT @n_ttlctn = SUM(convert(int,parm01))
        FROM #TEMPSLRESULT      
     END 
     ELSE
     BEGIN
        SELECT @n_ttlctn = SUM(CONVERT(INT,parm01))
        FROM #TEMPSLRESULT  WHERE PARM07=@parm07
     END

        update #TEMPSLRESULT
        SET PARM08 = CAST(@n_ttlctn AS integer)

        
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PARM01, PARM02, PARM03, PARM04,PARM06 --vince
   , PARM07,parm10
   FROM   #TEMPSLRESULT     
   WHERE parm09='O'
   ORDER BY PARM03,PARM06--vince
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getparm01,@c_getparm02  ,@c_getparm03,@c_getparm04,@c_getparm06,@c_getparm07,@n_getparm10 --vince
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
      
  SET @n_CntRec = 0  

  
 -- SELECT @c_getparm01 '@c_getparm01',@c_getparm02 '@c_getparm02',@c_getparm03 '@c_getparm03',@c_getparm07 '@c_getparm07'
  
  SET @n_CntRec = CONVERT( INT,@c_getparm01)
  SET @n_lineno = @n_getparm10 + 1
  
  WHILE @n_CntRec >1
  BEGIN
   INSERT INTO #TEMPSLRESULT
   (
      -- ROWID -- this column value is auto-generated
      PARM01,
      PARM02,
      PARM03,
      PARM04,
      PARM05,
      PARM06,
      PARM07,
      PARM08,PARM09,PARM10
   )
   SELECT TOP 1 PARM01,
      PARM02,
      PARM03,
      PARM04,
      PARM05,
      PARM06,
      PARM07,
      PARM08,'N',@n_lineno
   FROM #TEMPSLRESULT
   WHERE PARM01 = @c_getparm01
   AND PARM02 = @c_getparm02
   AND PARM03 = @c_getparm03
   AND PARM07 = @c_getparm07
   AND PARM06 = @c_getparm06--vince
   AND parm09='O'
      
   SET @n_CntRec = @n_CntRec - 1
   SET @n_lineno = @n_lineno + 1
   
  END
   
      
   FETCH NEXT FROM CUR_RESULT INTO @c_getparm01,@c_getparm02  ,@c_getparm03,@c_getparm04,@c_getparm06,@c_getparm07,@n_getparm10   --vince
   END        
   
---vince 
  IF  ISNULL(@parm07,'')=0
  begin
  INSERT INTO #TEMPRESULTOP
  (
   -- ROWID -- this column value is auto-generated
   PARM01,
   PARM02,
   PARM03,
   PARM04,
   PARM05,
   PARM06,
   PARM07,
   PARM08,
   PARM09,
   PARM10
  )
  SELECT PARM01,
      PARM02,
      PARM03,
      PARM04,
      PARM05,
      PARM06,
      PARM07,
      PARM08,PARM09,PARM10
    --  ,ROW_NUMBER() OVER (PARTITION BY PARM02 ORDER BY PARM03) AS recid
   FROM #TEMPSLRESULT
  --ORDER BY parm03
  ORDER BY parm03,PARM06   ---vince
  END 
  ELSE
  BEGIN 
    INSERT INTO #TEMPRESULTOP
  (
   -- ROWID -- this column value is auto-generated
   PARM01,
   PARM02,
   PARM03,
   PARM04,
   PARM05,
   PARM06,
   PARM07,
   PARM08,
   PARM09,
   PARM10
  )
  SELECT PARM01,
      PARM02,
      PARM03,
      PARM04,
      PARM05,
      PARM06,
      PARM07,
      PARM08,PARM09,PARM10
    --  ,ROW_NUMBER() OVER (PARTITION BY PARM02 ORDER BY PARM03) AS recid
   FROM #TEMPSLRESULT WHERE PARM07=@parm07
  --ORDER BY parm03
  ORDER BY parm03,PARM06   ---vince
  END
  ---vince 

  --SELECT * FROM #TEMPRESULTOP AS t
  --ORDER BY t.ROWID

    IF ISNULL(@parm05,'') <> '' AND ISNULL(@parm06,'') <> ''
      BEGIN                   
      IF ISNULL(@parm07,'')=0    --vince
      BEGIN
        SELECT PARM1=CONVERT(NVARCHAR(5),TSR.ROWID),PARM2=TSR.PARM08,PARM3=TSR.PARM02,PARM4=TSR.PARM03,PARM5=TSR.PARM04,
                     PARM6= TSR.PARM05,PARM7=TSR.PARM06,PARM8=PARM08,PARM9='',PARM10='',Key1='loadkey',Key2='',Key3='',Key4='',Key5=''
        FROM #TEMPRESULTOP TSR WITH (NOLOCK)  
        WHERE TSR.ROWID >= CONVERT(INT,@parm05) 
        AND TSR.ROWID <=   CONVERT(INT,@parm06)        
        ORDER BY TSR.ROWID--TSR.PARM03,CONVERT(INT,TSR.PARM10)
      END
        ELSE    --vince
        SELECT PARM1=CONVERT(NVARCHAR(5),TSR.ROWID),PARM2=TSR.PARM08,PARM3=TSR.PARM02,PARM4=TSR.PARM03,PARM5=TSR.PARM04,
                     PARM6= TSR.PARM05,PARM7=TSR.PARM06,PARM8=PARM08,PARM9='',PARM10='',Key1='loadkey',Key2='',Key3='',Key4='',Key5=''
        FROM #TEMPRESULTOP TSR WITH (NOLOCK)  
        WHERE TSR.ROWID >= CONVERT(INT,@parm05) 
        AND TSR.ROWID <=   CONVERT(INT,@parm06)   AND tsr.PARM07=@parm07 
        ORDER BY TSR.ROWID--TSR.PARM03,CONVERT(INT,TSR.PARM10)
     END      --vince   
     ELSE
     BEGIN
        IF ISNULL(@parm07,'')=0   --vince
       BEGIN
       SELECT PARM1=CONVERT(NVARCHAR(5),TSR.ROWID),PARM2=TSR.PARM08,PARM3=TSR.PARM02,PARM4=TSR.PARM03,PARM5=TSR.PARM04,
                     PARM6= TSR.PARM05,PARM7=TSR.PARM06,PARM8=PARM08,PARM9='',PARM10='',Key1='loadkey',Key2='',Key3='',Key4='',Key5=''
       FROM #TEMPRESULTOP TSR WITH (NOLOCK)        
        ORDER BY TSR.ROWID--TSR.PARM03,CONVERT(INT,TSR.PARM10)
      END
        ELSE   --vince
        SELECT PARM1=CONVERT(NVARCHAR(5),TSR.ROWID),PARM2=TSR.PARM08,PARM3=TSR.PARM02,PARM4=TSR.PARM03,PARM5=TSR.PARM04,
                     PARM6= TSR.PARM05,PARM7=TSR.PARM06,PARM8=PARM08,PARM9='',PARM10='',Key1='loadkey',Key2='',Key3='',Key4='',Key5=''
        FROM #TEMPRESULTOP TSR WITH (NOLOCK)  WHERE tsr.PARM07=@parm07      
        ORDER BY TSR.ROWID--TSR.PARM03,CONVERT(INT,TSR.PARM10)
     END      --vince           
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  

                                  
   END -- procedure   


GO