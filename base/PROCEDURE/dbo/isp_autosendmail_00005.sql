SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/*********************************************************************************/  
/* Stored Procedure: isp_AutoSendMail_00005                                      */  
/* Creation Date: 24-Feb-2021                                                    */  
/* Copyright: LFL                                                                */  
/* Written by: GHCHAN                                                            */  
/*                                                                               */  
/* Purpose: Construct and Return EmailTo, EmailCC, EmailSubject and EmailBody    */  
/*                                                                               */  
/* Called By: AutoSendEmail                                                      */  
/*                                                                               */  
/* PVCS Version: -                                                               */  
/*                                                                               */  
/* Updates:                                                                      */  
/* Date         Author   Ver        Purposes                                     */  
/* 24-Feb-2021  GHCHAN   1.0.0      Initial Development                          */  
/*********************************************************************************/  
  
CREATE PROC [dbo].[isp_AutoSendMail_00005]  
(  
    @b_Debug            INT               = 0
   ,@c_FileName         NVARCHAR(250)     = ''
   ,@c_EmailToList      NVARCHAR(500)     = ''   OUTPUT
   ,@c_EmailCCList      NVARCHAR(500)     = ''   OUTPUT
   ,@c_EmailBCCList     NVARCHAR(500)     = ''   OUTPUT
   ,@c_EmailSubject     NVARCHAR(200)     = ''   OUTPUT
   ,@c_EmailBody        NVARCHAR(MAX)     = ''   OUTPUT
   ,@b_Success          INT               = 0    OUTPUT    
   ,@n_ErrNo            INT               = 0    OUTPUT    
   ,@c_ErrMsg           NVARCHAR(250)     = ''   OUTPUT    
  
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS ON  
   SET QUOTED_IDENTIFIER ON   
   SET CONCAT_NULL_YIELDS_NULL ON    
           
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
 
   DECLARE @c_ExecArgs     NVARCHAR(1000) = ''
         , @SQL            NVARCHAR(MAX)  = ''
         
         , @c_DNNumber        NVARCHAR(20)   = ''
         , @c_NikeDDNumber    NVARCHAR(20)   = ''
         , @c_PONumber        NVARCHAR(20)   = ''
         , @c_Division        NVARCHAR(10)   = ''
         , @c_Code            NVARCHAR(20)   = ''
         , @c_Size            NVARCHAR(20)   = ''
         , @c_MaterialDescr   NVARCHAR(100)  = ''
         , @c_QTY             NVARCHAR(20)   = ''
         , @c_SpecialNotes    NVARCHAR(100)  = ''

         , @c_StorerKey       NVARCHAR(100)  = ''
         , @c_ConsigneeKey    NVARCHAR(100)  = ''
         , @c_DeliveryDate    NVARCHAR(100)  = ''
         , @c_ListName        NVARCHAR(100)  = ''
         , @c_Code2           NVARCHAR(100)  = ''
         , @c_Company         NVARCHAR(100)  = ''
         , @c_TotalCartons    NVARCHAR(20)   = ''   

   DECLARE @t_xml TABLE(
     XMLVal        XML NOT NULL
   )

   /********************************************/  
   /* Variables Declaration (END)              */  
   /********************************************/ 

   SET @b_Success = 1
   SET @n_ErrNo = 0
   SET @c_ErrMsg = ''

   SELECT @c_StorerKey     = ParamVal1
         ,@c_ListName      = ParamVal2
         ,@c_Code2         = ParamVal3
         ,@c_ConsigneeKey  = ParamVal4
         ,@c_DeliveryDate  = ParamVal5
   FROM dbo.EXG_FileHdr WITH (NOLOCK)
   WHERE [filename] = @c_FileName
   AND [status] ='9'

   --SELECT @c_EmailToList = 'guanhaochan@lflogistics.com'
   --      ,@c_EmailCCList = 'shunghoeloh@lflogistics.com'
   --      ,@c_EmailBCCList = ''
   
  SELECT  @c_EmailToList = RTRIM(ISNULL(c.Email1,'')) + CASE WHEN RIGHT(RTRIM(ISNULL(c.Email1,'')), 1) = ';' THEN '' ELSE ';' END + RTRIM(ISNULL(c.Email2,''))
       ,  @c_EmailCCList = CASE 
                              WHEN @c_StorerKey = 'NIKEMY' 
                              THEN 'MYSNikeTeam@lflogistics.com;MY.track.it@nike.com;' 
                              ELSE ''
                           END + RTRIM(ISNULL(c.Notes2,''))
       ,  @c_EmailBCCList = CASE 
                              WHEN @c_StorerKey = 'NIKESG' 
                              THEN 'CalvinKhor@LiFung.com;JayChua@LFLogistics.com;JoshuaHoong@LFLogistics.com;TehSuYu@lflogistics.com;NurfitriBujang@LFLogistics.com;SG.track.it@nike.com;NoorlinaSulaiman@LFLogistics.com;VincentCheang@LFLogistics.com;MohamadMasni@LFLogistics.com;SGPLFLogNIKE@LFLogistics.com;' 
                              WHEN @c_StorerKey = 'NIKEMY'
                              THEN 'CalvinKhor@LiFung.com;JayChua@LFLogistics.com;JoshuaHoong@LFLogistics.com;'
                              ELSE '' 
                           END
         , @c_EmailSubject = 'Auto Email ' + RTRIM(ISNULL(c.Company,'')) + ' ' + RTRIM(ISNULL(c.Address2,'')) + ' Nike Delivery Report ' + CONVERT(VARCHAR, o.DeliveryDate,106)
         , @c_Company = RTRIM(ISNULL(o.C_Company,'')) 
         , @c_TotalCartons = RTRIM(COUNT(DISTINCT o.loadkey + pd.DropID))
   FROM dbo.transmitlog3   AS t  WITH (NOLOCK)  
   JOIN dbo.orders         AS o  WITH (NOLOCK) ON t.key1  = o.orderkey  
   JOIN dbo.storer         AS c  WITH (NOLOCK) ON o.consigneekey = c.storerkey  
   JOIN dbo.LoadPlan       AS l  WITH (NOLOCK) ON l.LoadKey   = o.LoadKey   
   JOIN dbo.packheader     AS h  WITH (NOLOCK) ON h.orderkey  = o.orderkey  
   JOIN dbo.packdetail     AS pd WITH (NOLOCK) ON pd.pickslipno= h.pickslipno  
   WHERE o.storerkey = @c_StorerKey   
   AND t.transmitflag = '1'   
   AND c.Email1       <> ''   
   AND o.Status IN ( CASE WHEN @c_StorerKey  <> 'NIKESG' THEN '5' END, '9' )
   AND l.Status IN ( CASE WHEN @c_StorerKey  <> 'NIKESG' THEN '5' END, '9' )
   AND o.ConsigneeKey = @c_ConsigneeKey    
   AND o.deliverydate = @c_DeliveryDate  
   GROUP BY c.Email1, c.Email2, c.Notes2, c.address2, c.company, o.storerkey, o.C_Company, o.consigneekey, o.deliverydate 

 
   INSERT INTO @t_xml
   SELECT 
   CAST('<x>' + REPLACE(LineText1, ';', '</x><x>') + '</x>' AS XML)
   FROM [dbo].[EXG_FileDet] WITH (NOLOCK)
   WHERE [FileName] = @c_FileName
   AND [Status] = '9'
   ORDER BY SeqNo ASC
   OFFSET 5 ROWS
   FETCH NEXT 4000 ROWS ONLY


   SET @c_EmailBody     = N'<font face="Calibri">Dear Customer,</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">We would like to inform you on the delivery schedule of Nike products to your Retail Shop/Warehouse,</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri"><strong>Nike Delivery Report</strong></font><br>'  
                        + N'<br>'  
                        + N'<TABLE cellSpacing=0 cellPadding=4 width=1000 border=1><TBODY>'
                        + N'<TR>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Delivery Date</TH>'
                        + N'<TH class=v colSpan=8>'+ @c_DeliveryDate + '</TH></TR>'
                        + N'<TR>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Customer Name</TH>'
                        + N'<TH class=v colSpan=8>' + @c_Company + '</TH></TR>'
                        + N'<TR>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Ship To</TH>'
                        + N'<TH class=v colSpan=8>' + @c_ConsigneeKey + '</TH></TR>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Total Carton(s)</TH>'
                        + N'<TH class=v colSpan=8>' + @c_TotalCartons + '</TH></TR>'
                        + N'<TR>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">DN Number</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Nike DD Number</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">PO Number</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Division</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Code</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Size</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Material Descr</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">QTY</TH>'
                        + N'<TH style="text-align:left; background-color:#CAFF70">Special Notes</TH></TR>'
                        
                        DECLARE C_LOOPTBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                        SELECT [XMLVal].value(N'/x[1]', 'varchar(1000)') as DNNumber
                              ,[XMLVal].value(N'/x[2]', 'varchar(1000)') as NikeDDNumber
                              ,[XMLVal].value(N'/x[3]', 'varchar(1000)') as PONumber
                              ,[XMLVal].value(N'/x[4]', 'varchar(1000)') as Division
                              ,[XMLVal].value(N'/x[5]', 'varchar(1000)') as Code
                              ,[XMLVal].value(N'/x[6]', 'varchar(1000)') as Size
                              ,[XMLVal].value(N'/x[7]', 'varchar(1000)') as MaterialDescr
                              ,[XMLVal].value(N'/x[8]', 'varchar(1000)') as QTY
                              ,[XMLVal].value(N'/x[9]', 'varchar(1000)') as SpecialNotes
                        FROM @t_xml

                        OPEN C_LOOPTBL  
                        FETCH FROM C_LOOPTBL INTO  @c_DNNumber     
                                                 , @c_NikeDDNumber 
                                                 , @c_PONumber    
                                                 , @c_Division     
                                                 , @c_Code         
                                                 , @c_Size         
                                                 , @c_MaterialDescr
                                                 , @c_QTY          
                                                 , @c_SpecialNotes 

                        WHILE @@FETCH_STATUS <> -1  
                        BEGIN
                           SET @c_EmailBody += N'<TR>'
                                             + N'<TD class=L>' + SUBSTRING(@c_DNNumber     ,2, LEN(@c_DNNumber     )-2 )  + '</TD>'
                                             + N'<TD class=L>' + SUBSTRING(@c_NikeDDNumber ,2, LEN(@c_NikeDDNumber )-2 )  + '</TD>'
                                             + N'<TD class=L>' + SUBSTRING(@c_PONumber     ,2, LEN(@c_PONumber     )-2 )  + '</TD>'
                                             + N'<TD class=L>' + SUBSTRING(@c_Division     ,2, LEN(@c_Division     )-2 )  + '</TD>'
                                             + N'<TD class=L>' + SUBSTRING(@c_Code         ,2, LEN(@c_Code         )-2 )  + '</TD>'
                                             + N'<TD class=L>' + SUBSTRING(@c_Size         ,2, LEN(@c_Size         )-2 )  + '</TD>'
                                             + N'<TD class=L>' + SUBSTRING(@c_MaterialDescr,2, LEN(@c_MaterialDescr)-2 )  + '</TD>'
                                             + N'<TD class=R>' + SUBSTRING(@c_QTY          ,2, LEN(@c_QTY          )-2 )  + '</TD>'
                                             + N'<TD class=C>' + SUBSTRING(@c_SpecialNotes ,2, LEN(@c_SpecialNotes )-2 )  + '</TD></TR>'
                           
                           FETCH FROM C_LOOPTBL INTO  @c_DNNumber     
                                                    , @c_NikeDDNumber 
                                                    , @c_PONumber    
                                                    , @c_Division     
                                                    , @c_Code         
                                                    , @c_Size         
                                                    , @c_MaterialDescr
                                                    , @c_QTY          
                                                    , @c_SpecialNotes 
                           

                        END
                        CLOSE C_LOOPTBL  
                        DEALLOCATE C_LOOPTBL 


      SET @c_EmailBody  += N'</TBODY></TABLE><br>'  
                        + N'<font face="Calibri">Best Regards,</font><br>'
                        + N'<br>'  
                        + N'<font face="Calibri">Delivery Team</font><br>'
                        + N'<br>'  
                        + N'<font face="Calibri">Dear recipients, please do not reply the email.</font><br>'
                        + N'<br>'  
                        + N'<font face="Calibri"><strong>Any request, please communicate with Nike team. Thanks.</strong></font><br>'
   
   UPDATE t WITH (ROWLOCK)
   SET transmitflag = '9'
   FROM dbo.TRANSMITLOG3 AS t
   JOIN dbo.ORDERS AS o WITH (NOLOCK)
   ON t.key1 = o.OrderKey
   JOIN dbo.LoadPlan AS l WITH (NOLOCK)
   ON l.LoadKey = o.LoadKey --KH07
   JOIN dbo.PackHeader AS p WITH (NOLOCK)
   ON p.OrderKey = o.OrderKey --KH05
   JOIN dbo.PackDetail AS pd WITH (NOLOCK)
   ON pd.PickSlipNo = p.PickSlipNo
   JOIN dbo.STORER AS c WITH (NOLOCK)
   ON o.ConsigneeKey = c.StorerKey
   WHERE t.key3 = @c_StorerKey
   AND t.tablename = @c_Code2
   AND t.transmitflag = '1'
   --AND   c.Email1      <> ''
   AND o.Status IN (   CASE
                           WHEN @c_StorerKey <> 'NIKESG' THEN
                              '5'
                        END, '9'
                  ) --KH05
   AND l.Status IN (   CASE
                           WHEN @c_StorerKey <> 'NIKESG' THEN
                              '5'
                        END, '9'
                  ) --KH07
   AND o.ConsigneeKey = @c_ConsigneeKey
   AND o.DeliveryDate = @c_DeliveryDate;
 
  
  --SET @c_EmailToList = 'guanhaochan@lflogistics.com;limtzekeong@lflogistics.com'

  --SET @c_ConsigneeVal = SUBSTRING(@c_FileName, 1, CHARINDEX('_', @c_FileName, 0) -1)

  --SET @c_Consigneeval = SUBSTRING(@c_Consigneeval, PATINDEX('%[^0]%', @c_Consigneeval+'.'), LEN(@c_Consigneeval)) 

  -- SET @SQL = N' SELECT @c_EmailList=notes1 FROM dbo.Storer WITH (NOLOCK)'
  --          + N' WHERE StorerKey LIKE ''%' + @c_Consigneeval + '%'''
  --          + N' AND ConsigneeFor = ''UA'''
  --          + N' AND notes1 IS NOT NULL'
  --          + N' AND notes1 <> '''''
  --          + N' GROUP BY notes1'
   
  -- SET @c_ExecArgs = N' @c_EmailList NVARCHAR(500) OUTPUT'

  -- EXEC sp_ExecuteSql @SQL
  --                   ,@c_ExecArgs
  --                   ,@c_EmailList = @c_EmailList OUTPUT

   --SELECT 'CaiYunChen@LFLogistics.com'       [EmailTo]  
   --     , 'limtzekeong@lflogistics.com'      [EmailCC]  
   --     , @c_EmailSubject  [EmailSubject]  
   --     , @c_EmailBody     [EmailBody]  
   --FROM Orders (NOLOCK)  
   --WHERE OrderKey = @c_Key1   
   --AND ExternOrderkey = @c_Key2  
                                     
END -- End of Procedure

GO