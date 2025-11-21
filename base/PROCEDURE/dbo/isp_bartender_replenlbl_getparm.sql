SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_REPLENLBL_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-11-07 1.0  CSCHONG    WMS-6438                                        */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_REPLENLBL_GetParm]                      
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
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSELECT       NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_condition3      NVARCHAR(150),
      @c_condition4      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150)

declare  @c_Storerkey      nvarchar(20)
        ,@c_Wavekey       Nvarchar(20)
        ,@c_dropid        nvarchar(20)
        ,@c_Pnotes        nvarchar(250)
        ,@c_N1            nvarchar(20)
        ,@c_N2            nvarchar(20)
        ,@c_N3            nvarchar(20)
        ,@c_N4            nvarchar(20)
        ,@c_N5            nvarchar(20)
        ,@c_N6            nvarchar(20)
        ,@c_DelimiterSign nvarchar(5)
        ,@n_SeqNo         int
        ,@c_ColValue      nvarchar(250)
        ,@c_MaxN1         nvarchar(20)
        ,@c_MaxN2         nvarchar(20)
        ,@c_MaxN3         nvarchar(20)
        ,@c_MaxN4         nvarchar(20)
        ,@c_MaxN5         nvarchar(20) 
      
    
  DECLARE  @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000)  
         
             
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_condition3= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_DelimiterSign = '-'


   CREATE TABLE #TEMPORDPICK (
           RowID      INT IDENTITY(1,1) NOT NULL,
           Storerkey  NVARCHAR(20) NULL,
           Wavekey    NVARCHAR(20) NULL,
           Dropid     NVARCHAR(20) NULL,
           PNotes     NVARCHAR(250) NULL,
           PType      NVARCHAR(1) NULL,
           PLOC       NVARCHAR(20) NULL,
           PSKU       NVARCHAR(20) NULL
         )

   CREATE TABLE #TEMPPICKNOTES (
           RowID      INT IDENTITY(1,1) NOT NULL,
           Storerkey  NVARCHAR(20) NULL,
           Wavekey   NVARCHAR(20) NULL,
           Dropid   NVARCHAR(20) NULL,
           PNotes   NVARCHAR(250) NULL,
           N1       NVARCHAR(20) NULL,
           N2       NVARCHAR(20) NULL,
           N3       NVARCHAR(20) NULL,
           N4       NVARCHAR(20) NULL,
           N5       NVARCHAR(20) NULL,
           N6       NVARCHAR(20) NULL
               )

    INSERT INTO #TEMPORDPICK (Storerkey,Wavekey,Dropid,PNotes,PType,PLOC,PSKU)
    SELECT pd.storerkey,pd.wavekey,pd.dropid,pd.notes,LEFT(pd.notes,1),PD.loc,PD.sku 
    FROM  pickdetail pd (nolock) 
    WHERE pd.storerkey = @parm01 
    AND   pd.wavekey = @parm02
    and ISNULL(pd.notes,'') <> ''
    Order by LEFT(pd.notes,1),PD.loc,PD.sku 

    DECLARE C_loop_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT storerkey,            
             wavekey,
             dropid,
             PNotes
      FROM   #TEMPORDPICK WITH (NOLOCK)   
      order by rowid           
    --  Order by storerkey,            
    --         wavekey,
          --dropid,
          --PNotes  

     OPEN C_loop_Record             
     FETCH NEXT FROM C_loop_Record INTO @c_Storerkey   
                                      , @c_Wavekey
                                      , @c_dropid
                                      , @c_Pnotes 

    WHILE @@FETCH_STATUS=0   
    BEGIN

    SET @c_N1 = ''
    SET @c_N2 = ''
    SET @c_N3 = ''
    SET @c_N4 = ''
    SET @c_N5 = ''
    SET @c_N6 = ''

     DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT SeqNo, ColValue 
     FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_Pnotes)
     
     OPEN C_DelimSplit
     FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue

     WHILE (@@FETCH_STATUS=0) 
     BEGIN
           
     IF @n_SeqNo = 1
     BEGIN
      SET @c_N1 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 2
      BEGIN
      SET @c_N2 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 3
      BEGIN
      SET @c_N3 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 4
      BEGIN
      SET @c_N4 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 5
      BEGIN
      SET @c_N5 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 6
      BEGIN
      SET @c_N6 = @c_ColValue
     END
       

     FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue
     END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3
     
     CLOSE C_DelimSplit
     DEALLOCATE C_DelimSplit

      /*update #TEMPPICKNOTES
      SET N1 = @c_N1
         ,N2 = @c_N2
         ,N3 = @c_N3
         ,N4 = @c_N4
         ,N5 = @c_N5
         ,N6 = @c_N6
         WHERE Storerkey =  @c_Storerkey
         AND Wavekey     =  @c_Wavekey
         AND Dropid      =  @c_dropid*/

        IF NOT EXISTS (SELECT 1 FROM #TEMPPICKNOTES WHERE Storerkey = @c_Storerkey AND Wavekey =@c_Wavekey and Dropid=@c_dropid)
        BEGIN
         INSERT INTO #TEMPPICKNOTES (Storerkey,Wavekey,Dropid,PNotes,N1,N2,N3,N4,N5,N6)
         values (@c_Storerkey,@c_Wavekey,@c_dropid,@c_Pnotes,@c_N1,@c_N2,@c_N3,@c_N4,@c_N5,@c_N6)
        END
         
    FETCH NEXT FROM C_loop_Record INTO @c_Storerkey   
                                     , @c_Wavekey
                                     , @c_dropid
                                     , @c_Pnotes 

     END                 
     CLOSE C_loop_Record            
     DEALLOCATE C_loop_Record  

    --select * From #TEMPPICKNOTES
    --where CAST(N4 as int) between CAST (@parm09 AS Int ) AND CAST (@parm10 AS Int )
   -- where CAST(substring(N4,1,CHARINDEX('|',N4)-1) as int) between CAST (@parm09 AS Int ) AND CAST (@parm10 AS Int ) 


   select   @c_MaxN3=MAX(cast(n3 as int)),
            @c_MaxN2 =MAX(cast(n2 as int)),
            @c_MaxN4=MAX(cast(n4 as int)),
            @c_MaxN5 = max(cast(n5 as int))
    from #TEMPPICKNOTES 
    group by  wavekey

    update #TEMPPICKNOTES
    SET  N2 = N2 +'|' + @c_MaxN2
        ,N3 = N3 +'|' + @c_MaxN3
        ,N4 = N4 +'|' + @c_MaxN4
        ,N5 = N5 +'|' + @c_MaxN5
     WHERE Storerkey = @c_Storerkey
     AND Wavekey = @c_Wavekey
        
--select CAST(substring(N4,1,CHARINDEX('|',N4)-1) as int) as N4,* From #TEMPPICKNOTES

SET @c_SQLOrdBy = ' Order by RowID'

    --SET @c_SQLSELECT = N' SELECT storerkey,wavekey,dropid,pnotes'
    SET @c_SQLSELECT = 'SELECT PARM1=wavekey,PARM2=dropid,PARM3=N3,PARM4=N2,PARM5=N4,PARM6=N5,PARM7=Storerkey, '+
                       'PARM8='''',PARM9='''',PARM10='''',Key1=''dropid'',Key2='''',Key3='''',Key4='''','+
                       ' Key5= '''' '  +  
                       +' From #TEMPPICKNOTES '
                       + 'WHERE Storerkey = @parm01 AND Wavekey = @parm02 '   
       
   
    IF ISNULL(@parm03,'') <> '' AND ISNULL(@parm04,'') <> ''
    BEGIN
      SET @c_condition1 = ' AND dropid between @parm03 and @parm04'
    END
    
    IF ISNULL(@parm05,'') <> '' AND ISNULL(@parm06,'') <> ''
    BEGIN
      SET @c_condition2 = ' AND N1 between @parm05 and @parm06'
    END
    
    IF ISNULL(@parm07,'') <> '' AND ISNULL(@parm08,'') <> ''
    BEGIN
     -- SET @c_condition3 = ' AND N5 between @parm07 and @parm08'
     SET @c_condition3 = ' AND CAST(substring(N5,1,CHARINDEX(''|'',N5)-1) as int) between CAST (@parm07 AS Int ) AND CAST (@parm08 AS Int ) '
    END
    
    IF ISNULL(@parm09,'') <> '' AND ISNULL(@parm10,'') <> ''
    BEGIN
      --SET @c_condition4 = ' AND N4 between @parm09 and @parm10'
      SET @c_condition4 = ' AND CAST(substring(N4,1,CHARINDEX(''|'',N4)-1) as int) between CAST (@parm09 AS Int ) AND CAST (@parm10 AS Int ) '
    END


    SET @c_sql = @c_sqlselect + CHAR(13) + @c_condition1 + CHAR(13) +@c_condition2 
             + CHAR(13) + @c_condition3 + CHAR(13) + @c_condition4 + CHAR(13) + @c_SQLOrdBy + CHAR(13)

    SET @c_ExecArguments = N'@parm01     NVARCHAR(20)'
                         + ',@parm02     NVARCHAR(20)'
                         + ',@parm03     NVARCHAR(20)'
                         + ',@parm04     NVARCHAR(20)'
                         + ',@parm05     NVARCHAR(20)'
                         + ',@parm06     NVARCHAR(20)'
                         + ',@parm07     NVARCHAR(20)'
                         + ',@parm08     NVARCHAR(20)'
                         + ',@parm09     NVARCHAR(20)'
                         + ',@parm10     NVARCHAR(20)'
                  
   EXEC sp_ExecuteSql @c_sql 
                     ,@c_ExecArguments
                     ,@parm01
                     ,@parm02
                     ,@parm03
                     ,@parm04
                     ,@parm05
                     ,@parm06
                     ,@parm07
                     ,@parm08
                     ,@parm09
                     ,@parm10 
                          
--select * from #TEMPORDPICK
  -- END         
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO