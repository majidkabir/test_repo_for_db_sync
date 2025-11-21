SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store Procedure:  isp_UCC_Carton_wave_Label_41                           */
/* Creation Date: 7-Mar-2016                                                */
/* Copyright: IDS                                                           */
/* Written by: CSCHONG                                                      */
/*                                                                          */
/* Purpose:  To print Ucc Carton Label 41                                   */
/*                                                                          */
/* Input Parameters: Parm01,Parm02,Parm03,Parm04,Parm05                     */
/*                                                                          */
/* Output Parameters:                                                       */
/*                                                                          */
/* Usage:                                                                   */
/*                                                                          */
/* Called By:  r_dw_ucc_carton_wave_label_41                                */
/*                                                                          */
/* PVCS Version: 1.1                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author   Ver  Purposes                                      */
/* 23-JUN-2016  CSCHONG  1.1  Fix sorting issue (CS01)                      */
/* 12-JUL-2016  CSCHONG  1.2  Print by RDT Spooler (CS02)                   */
/* 22-FEB-2018  CSCHONG  1.3  WMS-3953-Print by bartender (CS03)            */
/* 17-Jan-2019  TLTING   1.3  tmp add primary key                           */   
/* 23-Apr-2019  CSCHONG  1.4  Performance tunning add commit tran(CS04)     */
/*****************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_wave_Label_41] (
         @c_wavekey NVARCHAR(10) 
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


  DECLARE  @c_storerkey      NVARCHAR(20)
        ,  @c_Pickslipno     NVARCHAR(20)
        ,  @c_labelno        NVARCHAR(20)
        ,  @c_RptType        NVARCHAR(10)
        ,  @c_cartonno    NVARCHAR(10)
        ,  @n_id          INT
        ,  @n_qty         INT
        ,  @c_sku         NVARCHAR(20)
        ,  @c_getlabelno     NVARCHAR(20)   --(CS01)
        ,  @c_style       NVARCHAR(20)
        ,  @n_getqty      INT
        ,  @n_rowid       INT
        ,  @n_getrowid    INT
        ,  @n_CntRec      INT
        ,  @c_PrintbyBT   NVARCHAR(1)  --(CS03)
        
   --CS01a start
   DECLARE @c_Llabelno        NVARCHAR(20)
          ,@c_label_content NVARCHAR(4000)   
          ,@c_Lsku          NVARCHAR(20)  
          ,@n_Lqty          INT
          ,@c_Getlblcontent NVARCHAR(4000)   
          
 --CS02 start
 DECLARE @c_Getprinter     NVARCHAR(10),
         @c_UserId         NVARCHAR(20),
         @c_GetDatawindow  NVARCHAR(40),
         @c_ReportID       NVARCHAR(10),
         @n_noofParm       INT,
         @b_success        int,
         @n_err            int,
         @c_errmsg         NVARCHAR(255)

  --CS04 Start                          
  DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT

    --CS04 End 

   SET @c_storerkey     = ''     
   SET @c_Pickslipno    = ''    
   SET @c_labelno       = ''  
   SET @c_RptType       = '0'
   
   --CS01a start
   SET @c_Llabelno=''
   SET @c_label_content=''
   SET @c_Lsku=''
   SET @n_Lqty=0
   
   SET @c_Getprinter = ''
   SET @c_ReportID='UCClbconso'
   SET @c_UserId= SUSER_NAME()
   SET @n_noofParm = 5
   SET @c_PrintbyBT = 'N'                --(CS03)
   
   
   SELECT @c_Getprinter = defaultprinter
   FROM RDT.RDTUser AS r WITH (NOLOCK)
   WHERE r.UserName = @c_UserId
   
   IF ISNULL(@c_Getprinter,'') = ''
   BEGIN
      SET @c_Getprinter = 'PDF'
   END


   CREATE TABLE #TMP_GETCOLUMN (
          [RowID]    [INT] IDENTITY(1,1) NOT NULL primary KEY,
          col01     NVARCHAR(20) NULL,
          col02     NVARCHAR(20) NULL,
          col03     NVARCHAR(20) NULL,
          col04     NVARCHAR(20) NULL,
          col05     NVARCHAR(30) NULL,
          RptType   NVARCHAR(10) NULL)

   CREATE TABLE #TMP_WAVEPICK (
          [ID]    [INT] IDENTITY(1,1) NOT NULL primary KEY, 
          Storerkey    NVARCHAR(20) NULL,
          Orderkey     NVARCHAR(20) NULL,
          Loadkey      NVARCHAR(20) NULL,
          wavekey      NVARCHAR(20) NULL,
          Pickslipno   NVARCHAR(20) NULL,
          Labelno      NVARCHAR(20) NULL,
          SKU          NVARCHAR(20) NULL,
          qty          INT,
          CartonNo     INT,
          Updatesource NVARCHAR(10) NULL,
          Rowno        INT)
          
   CREATE TABLE #TMP_sortOutput
   (labelno NVARCHAR(20), Label_content NVARCHAR(4000) )       --CS01a 


  INSERT INTO #TMP_WAVEPICK (Storerkey,Orderkey,Loadkey,wavekey,Pickslipno,Labelno,SKU,qty,CartonNo,UpdateSource,rowno)


  SELECT DISTINCT ORD.Storerkey,ORD.ORDERKEY,ORD.LOADKEY,WVDET.WAVEKEY,PIDET.PICKSLIPNO
 ,PADET.Labelno,S.Style,PADET.qty,PADET.CartonNo,ORD.UpdateSource,0
  FROM wavedetail WVDET WITH (NOLOCK)
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = WVDET.ORDERKEY
  JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.ORDERKEY = ORD.ORDERKEY
  JOIN PACKDETAIL PADET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno
 -- JOIN PACKHEADER PAH WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
 JOIN SKU S (NOLOCK) ON PADET.SKU = S.SKU AND PADET.Storerkey = S.StorerKey
  WHERE WVDET.WaveKey = @c_wavekey
  AND PIDET.UOM in ('6','7')
 -- GROUP BY ORD.Storerkey,ORD.ORDERKEY,ORD.LOADKEY,WVDET.WAVEKEY,PIDET.PICKSLIPNO
 --,PADET.Labelno,PADET.SKU,PADET.CartonNo,ORD.UpdateSource
  ORDER BY PADET.Labelno
  
  /*CS01a Start*/
  DECLARE CUR_labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
  SELECT DISTINCT Labelno FROM #TMP_WAVEPICK
  ORDER BY labelno--,style
  
  OPEN CUR_labelno

  FETCH NEXT FROM CUR_labelno INTO @c_Llabelno
                                    
   WHILE @@FETCH_STATUS <> -1
   BEGIN       
      
      SET @c_label_content=''
      
      DECLARE CUR_labelSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT sku, Qty FROM #TMP_WAVEPICK 
      WHERE labelno=@c_Llabelno
      ORDER BY sku
        
       OPEN CUR_labelSKU
    
       FETCH NEXT FROM CUR_labelSKU INTO @c_Lsku, @n_Lqty
       WHILE @@FETCH_STATUS = 0
       BEGIN
         
         SET @c_label_content=@c_label_content+LTRIM(RTRIM(@c_Lsku))+LTRIM(RTRIM(CONVERT(NVARCHAR(10),@n_Lqty)))+CHAR(13)

       FETCH NEXT FROM CUR_labelSKU INTO @c_Lsku, @n_Lqty
       END 
       CLOSE CUR_labelSKU
       DEALLOCATE CUR_labelSKU

  
          INSERT INTO #TMP_sortOutput (labelno, Label_content) VALUES (@c_Llabelno, @c_label_content)

   FETCH NEXT FROM CUR_labelno INTO @c_Llabelno                                   
      
   END
   CLOSE CUR_labelno
   DEALLOCATE CUR_labelno   
  
  /*CS01a End*/
  
   

 DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 

 
   SELECT DISTINCT p.storerkey, P.pickslipno,t.labelno ,p.cartonno,p.updatesource,label_content
   FROM #tmp_sortOutput  t 
   JOIN #TMP_WAVEPICK P ON P.labelno=t.labelno
   ORDER BY label_content,t.labelno

  OPEN CUR_StartRecLoop

  FETCH NEXT FROM CUR_StartRecLoop INTO @c_storerkey
                               ,@c_pickslipno                     --(CS01)
                               ,@c_labelno   
                               ,@c_cartonno
                               ,@c_RptType    
                               ,@c_Getlblcontent
                               -- ,@c_sku 
                               -- ,@n_getrowid                         

   WHILE @@FETCH_STATUS <> -1
   BEGIN

   IF NOT EXISTS (SELECT 1 FROM #TMP_GETCOLUMN where col02 = @c_pickslipno and col03=@c_cartonno)        --(CS01)
   BEGIN
     INSERT INTO #TMP_GETCOLUMN (col01,col02,col03,col04,Rpttype)
     VALUES(@c_storerkey,@c_pickslipno,@c_cartonno,@c_cartonno,@c_RptType)          --(CS01)
     
     SET @c_GetDatawindow = ''
     
     /*CS03 Start*/
     
     IF @c_RptType = 'R01'
     BEGIN
      SET @c_PrintbyBT = 'Y'
     END 
     
     /*CS03 End*/
     
     IF @c_RptType IN ('001','002')
     BEGIN
         SET @c_GetDatawindow  = 'r_dw_ucc_carton_label_41_2'
     END
     ELSE
      BEGIN
         SET @c_GetDatawindow  = 'r_dw_ucc_carton_label_41_1'
      END
      
     IF @c_PrintbyBT='N'    --CS01 start
     BEGIN
      IF ISNULL(@c_GetDatawindow,'') <> ''
         BEGIN   
         BEGIN TRAN         --Cs04                    
           EXEC isp_PrintToRDTSpooler 
                @c_ReportType = @c_ReportID, 
                @c_Storerkey  = @c_Storerkey,
                @b_success     = @b_success OUTPUT,
                @n_err           = @n_err OUTPUT,
                @c_errmsg     = @c_errmsg OUTPUT,
                @n_Noofparam  = @n_noofParm,
                @c_Param01    = @c_storerkey,
                @c_Param02    = @c_pickslipno,
                @c_Param03    = @c_cartonno,
                @c_Param04    = @c_cartonno,
                @c_Param05    = @c_RptType,
                @c_Param06    = '',
                @c_Param07    = '',
                @c_Param08    = '',
                @c_Param09    = '',
                @c_Param10    = '',
                @n_Noofcopy   = 1,
                @c_UserName   = @c_UserId,
                @c_Facility   = '',
                @c_PrinterID  = @c_Getprinter,
                @c_Datawindow = @c_GetDatawindow,
                @c_IsPaperPrinter = 'Y'
      
               IF @b_success <> 1 
               BEGIN
                   --SELECT @n_continue = 3
                    RoLLBACK TRAN        --Cs01
                  GOTO QUIT_SP   
               END
            --Cs04 Start
             WHILE @@TRANCOUNT > 0
                BEGIN
                 COMMIT TRAN
                END    

            --CS04 End

         END 
     
     END
     ELSE
     BEGIN
       EXEC isp_BT_GenBartenderCommand        
          @cPrinterID = @c_Getprinter
         ,@c_LabelType = 'RETAILLBL'
         ,@c_userid = @c_UserId
         ,@c_Parm01 = @c_storerkey
         ,@c_Parm02 = @c_pickslipno
         ,@c_Parm03 = @c_cartonno
         ,@c_Parm04 = @c_cartonno
         ,@c_Parm05 = ''
         ,@c_Parm06 = ''
         ,@c_Parm07 = ''
         ,@c_Parm08 = ''
         ,@c_Parm09 = ''
         ,@c_Parm10 = ''
         ,@c_Storerkey = @c_Storerkey
         ,@c_NoCopy = 1
         ,@c_Returnresult = 'N' 
         ,@n_err = @n_Err OUTPUT
         ,@c_errmsg = @c_ErrMsg OUTPUT    

         IF @n_err <> 0
         BEGIN
            RoLLBACK TRAN       --CS01
            GOTO  QUIT_SP   
         END
         --Cs04 Start
          WHILE @@TRANCOUNT > 0
          BEGIN
            COMMIT TRAN
          END    

            --CS04 End

     END     --CS01 End
     
   END

   FETCH NEXT FROM CUR_StartRecLoop INTO @c_storerkey
                                 ,@c_pickslipno                 --(CS01)
                                 ,@c_labelno 
                                 ,@c_cartonno
                                 ,@c_RptType 
                                 ,@c_Getlblcontent
                                  --  ,@c_sku        
                                  --  ,@n_getrowid   

   END
   CLOSE CUR_StartRecLoop
   DEALLOCATE CUR_StartRecLoop


  SELECT col01 ,col02, col03, col04,Rpttype--,RowID
  FROM #TMP_GETCOLUMN
  --order by rowid
  
END
   --CS04 start
   WHILE @@TRANCOUNT <  @n_StartTCnt
   BEGIN
    BEGIN   TRAN
   END

   --CS04 End

QUIT_SP:


GO