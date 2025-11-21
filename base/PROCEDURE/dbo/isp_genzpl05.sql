SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GENZPL05                                       */  
/* Creation Date: 30-AUG-2024                                           */  
/* Copyright: Maersk                                                    */  
/* Written by:CHONGCS                                                   */  
/*                                                                      */  
/* Purpose: WMS-25465 AU_LVS_Internal_Pallet_Label_ZPL                  */  
/*                                                                      */  
/* Called By: isp_GenZPL_interface                                      */  
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 30-AUG-2024  CSCHONG   1.0   Devops Scripts Combine                  */
/* 12-SEP-2024  CSCHONG   1.1   WMS-25465 revised field logic (CS01)    */
/************************************************************************/  
  
CREATE    PROC isp_GENZPL05 (  
    @c_StorerKey    NVARCHAR( 15)  
   ,@c_Facility     NVARCHAR( 5)  
   ,@c_ReportType   NVARCHAR( 10)  
   ,@c_Param01      NVARCHAR(250)  
   ,@c_Param02      NVARCHAR(250)  
   ,@c_Param03      NVARCHAR(250)  
   ,@c_Param04      NVARCHAR(250)  
   ,@c_Param05      NVARCHAR(250)  
   ,@c_PrnTemplate  NVARCHAR(MAX)  
   ,@c_ZPLCode      NVARCHAR(MAX) OUTPUT  
   ,@b_success      INT           OUTPUT  
   ,@n_err          INT           OUTPUT  
   ,@c_errmsg       NVARCHAR(250) OUTPUT  
    )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_Externorderkey     NVARCHAR( 50) ,  
           @c_company            NVARCHAR( 45) ,  
           @c_trackingNo         NVARCHAR( 40) ,  
           @c_ORDDate            NVARCHAR( 10) ,  
           @n_Continue           INT,  
           @n_starttcnt          INT,  
           @c_trmlogkey          NVARCHAR(20)  
  
  DECLARE @c_field01             NVARCHAR(80) = '',  
          @c_field02             NVARCHAR(80) = '',  
          @c_field03             NVARCHAR(80) = '',  
          @c_field04             NVARCHAR(80) = '',  
          @c_field05             NVARCHAR(80) = '',  
          @c_field06             NVARCHAR(80) = '',  
          @c_field07             NVARCHAR(80) = '',  
          @c_field08             NVARCHAR(500) = '',  
          @c_field09             NVARCHAR(80) = '',  
          @c_field10             NVARCHAR(80) = '',  
          @c_field11             NVARCHAR(150) = '',  
          @c_field12             NVARCHAR(80) = '',  
          @c_field13             NVARCHAR(80) = '',  
          @c_field14             NVARCHAR(80) = '',  
          @c_field15             NVARCHAR(80) = '',  
          @c_field16             NVARCHAR(80) = '',  
          @c_field17             NVARCHAR(150) = '',  
          @c_field18             NVARCHAR(150) = '',  
          @c_field19             NVARCHAR(150) = '',    
          @c_field20             NVARCHAR(150) = '',   
          @c_field21             NVARCHAR(150) = '',   
          @c_field22             NVARCHAR(150) = '',  
          @c_field23             NVARCHAR(150) = '',  
          @c_field24             NVARCHAR(150) = '',  
          @c_field25             NVARCHAR(150) = '',  
          @c_field26             NVARCHAR(150) = '',  
          @c_field27             NVARCHAR(150) = '',  
          @c_field28             NVARCHAR(4000) = '',  
          @c_field29             NVARCHAR(150) = '',  
          @c_field30             NVARCHAR(150) = '',  
          @c_field31             NVARCHAR(150) = '',  
  
          @c_orderkey            NVARCHAR(20)  = '',  
          @c_codelen             NVARCHAR(20)  = '', 
          @c_RNolen              NVARCHAR(20)  = '', 
          @n_codelen             INT   = 0,  
          @n_RNolen              INT   = 0, 
          @c_long                NVARCHAR(500) = '',  
          @c_short               NVARCHAR(10)  = '',
          @c_udf01               NVARCHAR(60)  = '',    
          @c_KeyName             NVARCHAR(18)  = '',    
          @c_RunningNo           NVARCHAR(10)  = '',
          @c_OpenPLT             NVARCHAR(1)   = 'N',         --CS01 S
          @c_Shipperkey          NVARCHAR(45)  = '',
          @c_CTUDF03             NVARCHAR(30)  = '',
          @c_connoteNo           NVARCHAR(30)  = '',
          @c_CurSeqNo            NVARCHAR(10)  = '',
          @c_SeqNo               NVARCHAR(10)  = '',
          @n_SeqNo               INT = 0,
          @c_PLTDETUDF05         NVARCHAR(60) = '',
          @n_CtnCaseID           INT,
          @c_clklong             NVARCHAR(4000) = '', 
          @c_clkudf01            NVARCHAR(80) = '', 
          @c_clkudf05            NVARCHAR(80) = '' 
       
  
   SELECT @n_starttcnt=@@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_Errmsg = '', @c_ZPLCode = ''  
  
   SELECT @c_udf01   = ISNULL(udf01,'')                     
   FROM codelkup (NOLOCK) WHERE listname ='GENPLTLBL' AND Storerkey = @c_Param02  

     SELECT TOP 1 
          @c_field02      = OH.C_Company,  
          @c_field03      = OH.C_Address1,  
          @c_field04      = ISNULL(OH.C_Address4,''),  
          @c_field05      = ISNULL(oh.C_State,'')  + ',' + ISNULL(oh.c_zip,''),  
          @c_field06      = ISNULL(OH.C_Country,'') ,  
          @c_field07      = OH.ShipperKey,
          @c_orderkey     = OH.orderkey,
          @c_Field15      = convert(nvarchar(10),OIF.OrderInfo06,23),
          @c_field16      = ISNULL(OIF.OrderInfo01,''),
          @c_field17      = ISNULL(OIF.OrderInfo02,''),
          @c_field18      = ISNULL(OIF.OrderInfo03,'')
  FROM PALLETDETAIL PDET WITH (NOLOCK)
  JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PDET.userdefine01
  LEFT JOIN OrderInfo OIF WITH (NOLOCK) ON OIF.orderkey = OH.orderkey
  WHERE PDET.palletkey = @c_Param01
  AND PDET.storerkey = @c_Param02
  AND PDET.userdefine03= @c_Param03

   --CS01
   SELECT @c_codelen   = ISNULL(udf05,'')  
         ,@c_RNolen   = ISNULL(udf04,'')  
         ,@c_short     = ISNULL(short,'')
         ,@c_long    = ISNULL(Long,'')  
         ,@c_clkudf01   = ISNULL(udf01,'')
   FROM codelkup (NOLOCK) 
   WHERE listname ='GENZPL_PLT' AND code = @c_field07 AND Storerkey = @c_Param02  

   IF ISNUMERIC(@c_codelen) = 1
   BEGIN
      SET @n_codelen = CAST(@c_codelen AS INT)
   END 

   IF ISNUMERIC(@c_RNolen) = 1
   BEGIN
      SET @n_RNolen = CAST(@c_RNolen AS INT)
   END
  

    IF EXISTS (SELECT 1 FROM palletdetail pd (nolock) 
                      Left Join cartontrack ct (nolock) on pd.palletkey = ct.labelno and pd.storerkey = ct.keyname
                      LEft Join mbol mb (nolock) on pd.userdefine03 = mb.externmbolkey
                      where pd.userdefine03 = @c_Param03 and pd.userdefine05 = ''  
            --and mb.status = '0' 
            and pd.storerkey = @c_Param02 and pd.status = '9' and ct.trackingno is null
            and pd.palletkey = @c_Param01)
  BEGIN
    SET @c_OpenPLT = 'Y'
  END

  --select @c_OpenPLT '@c_OpenPLT', @c_short '@c_short' , @c_long '@c_long',@n_RNolen '@n_RNolen', @c_field07 '@c_field07'

  IF @c_OpenPLT = 'Y'
  BEGIN

    -- SELECT @c_clklong    = ISNULL(Long,'')  
   --      ,@c_clkudf01   = ISNULL(udf01,'')
     --,@c_clkudf05   = ISNULL(udf05,'')
   --FROM codelkup (NOLOCK) 
   --WHERE listname ='GENZPL_PLT' AND code = @c_field07 AND Storerkey = @c_Param02  

      IF @c_short ='CON'
      BEGIN
        SET @c_KeyName = @c_long--@c_Param02 +'_GENZPL'  
        EXECUTE dbo.nspg_GetKey  
                               @c_KeyName,  
                               @n_RNolen,--9 ,  
                               @c_RunningNo       OUTPUT,  
                               @b_success         OUTPUT,  
                               @n_err             OUTPUT,  
                               @c_errmsg          OUTPUT  
  
        SET @c_connoteNo = @c_long + @c_RunningNo  
  
  
       END  

  END
  ELSE  
    BEGIN  
       SELECT TOP 1 @c_connoteNo = Cartontrack.UDF03 
       FROM cartontrack (nolock)   
       Join palletdetail (nolock) on cartontrack.labelno = palletdetail.UserDefine05  
       where palletdetail.status = '9'
       and  palletdetail.userdefine03 = @c_Param03 and palletdetail.storerkey = @c_Param02  
       and palletdetail.PalletKey =  @c_Param01 
       
    END  

  SET @c_field11 = @c_connoteNo

  --select @c_connoteNo '@c_connoteNo'

    SELECT TOP 1 @c_PLTDETUDF05 = palletdetail.Palletkey
    FROM cartontrack (nolock) 
    Join palletdetail (nolock) on cartontrack.labelno = palletdetail.palletkey 
    where isnull(palletdetail.userdefine05,'') = '' 
    and palletdetail.status = '9'
    and palletdetail.userdefine03 = @c_Param03 and palletdetail.storerkey = @c_Param02 

  --CS01 E

   --SET  @c_field01  = @c_udf01 + @c_Param01     --CS01 E
   SET  @c_field09  = @c_Param01
   SET  @c_field10  = @c_Param03
  

  SELECT @c_field25      = MIN(convert(nvarchar(10),OH.DeliveryDate,23)),
         @c_field26      = MAX(convert(nvarchar(10),OH.DeliveryDate,23))
  FROM PALLETDETAIL PDET WITH (NOLOCK)
  JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PDET.userdefine01
  WHERE PDET.palletkey = @c_Param01
  AND PDET.storerkey = @c_Param02
  AND PDET.userdefine03= @c_Param03

  SELECT @c_field19      = CAST(CAST((PLT.GrossWgt/1000) as decimal(10,2)) as nvarchar(20)),
         @c_field20      = CAST(CAST((PLT.Length/100) as decimal(10,2)) as nvarchar(20)),
         @c_field21      = CAST(CAST((PLT.Width/100) as decimal(10,2)) as nvarchar(20)),
         @c_field22      = CAST(CAST((PLT.Height/100) as decimal(10,2)) as nvarchar(20)),
         @c_field23      = CAST(CAST((PLT.Length*PLT.Width*PLT.Height)/1000000 as decimal(10,2)) as nvarchar(20))
  FROM PALLET PLT WITH (NOLOCK)
  WHERE PLT.palletkey = @c_Param01
  AND PLT.storerkey = @c_Param02
  --AND PDET.userdefine03= @c_Param03

  SELECT @n_CtnCaseID = COUNT(DISTINCT PDET.CaseId)
  FROM PALLETDETAIL PDET WITH (NOLOCK)
  WHERE PDET.palletkey = @c_Param01
  AND PDET.storerkey = @c_Param02


   SET @c_field27 = CAST(@n_CtnCaseID as NVARCHAR(10))
   SET @c_field28 = isnull(@c_clklong,'') 
   -- Parameter mapping  
  -- SELECT @c_field01      = (RIGHT(REPLICATE('0', @n_codelen) + CAST(@c_Param02 AS VARCHAR), @n_codelen)),--(RIGHT(REPLICATE('0', 18) + CAST(@c_Param02 AS VARCHAR(18)), 18)), --CS01  
   SELECT @c_field08      = s.Company + CHAR(13), --+ ISNULL(s.Address1,'')  + CHAR(13) + 
            --            ISNULL(s.Address2,'') + CHAR(13) + ISNULL(s.State,'')  + ',' + ISNULL(s.zip,'') + CHAR(13) + 
                --ISNULL(s.Country,''),
          @c_field12      = ISNULL(s.Address1,'') ,
          @c_field13      = ISNULL(s.State,'')  + ',' + ISNULL(s.zip,'') ,
          @c_field14      = ISNULL(s.Country,'')
   FROM STORER s (nolock) 
   WHERE s.StorerKey = @c_Param02
  
    --CS01 S
  SET @c_trackingNo  = ''
  SET @c_SeqNo = '00001'
  SET @c_CurSeqNo ='00001'
  SET @n_Seqno = 1

  IF @c_OpenPLT = 'Y'
  BEGIN 
       SELECT @c_trackingNo  = @c_connoteNo + @c_clkUDF01 + RIGHT(REPLICATE('0',CAST(@c_codelen AS INT))+'1',CAST(@c_codelen AS INT))--@c_CurSeqNo
  END
  ELSE
  BEGIN
      --select @c_CurSeqNo = MAX(right(ct.Trackingno,@n_codelen))
       --                   FROM  cartontrack ct (nolock) 
          --      Join  Palletdetail pd (nolock) on ct.labelno = pd.palletkey 
          --      and ct.keyname = pd.storerkey 
          --      where pd.userdefine03 = @c_Param03 and pd.storerkey = @c_Param02
          --      AND isnull(pd.userdefine05,'') = ''

       select @c_CurSeqNo =  MAX(RIGHT(TRACKINGNO, CAST(@c_codelen AS INT)))
       FROM CARTONTRACK (NOLOCK) 
       WHERE UDF03 = @c_connoteNo


       IF ISNULL(@c_CurSeqNo,'') = ''
       BEGIN
        SET @n_seqno = CAST(@c_CurSeqNo AS INT)
       END
       ELSE
       BEGIN
          SET @n_seqno = CAST(@c_CurSeqNo AS INT) --+ 1
       END

     set @c_SeqNo = Right('00000' + CONVERT(NVARCHAR, @n_seqno), 5)

     SELECT @c_trackingNo  =  @c_connoteNo + @c_clkUDF01 + RIGHT(REPLICATE('0',CAST(@c_codelen AS INT))+CAST(@n_seqno + 1 AS NVARCHAR),CAST(@c_codelen AS INT))

  END
  --CS01 E
  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field01>', RTRIM( ISNULL( @c_trackingNo,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field02>', RTRIM( ISNULL( @c_field02,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field03>', RTRIM( ISNULL( @c_field03,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field04>', RTRIM( ISNULL( @c_field04,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field05>', RTRIM( ISNULL( @c_field05,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field06>', RTRIM( ISNULL( @c_field06,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field07>', RTRIM( ISNULL( @c_field07,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field08>', RTRIM( ISNULL( @c_field08,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field09>', RTRIM( ISNULL( @c_field09,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field10>', RTRIM( ISNULL( @c_field10,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field11>', RTRIM( ISNULL( @c_field11,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field12>', RTRIM( ISNULL( @c_field12,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field13>', RTRIM( ISNULL( @c_field13,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field14>', RTRIM( ISNULL( @c_field14,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field15>', RTRIM( ISNULL( @c_field15,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field16>', RTRIM( ISNULL( @c_field16,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field17>', RTRIM( ISNULL( @c_field17,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field18>', RTRIM( ISNULL( @c_field18,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field19>', RTRIM( ISNULL( @c_field19,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field20>', RTRIM( ISNULL( @c_field20,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field21>', RTRIM( ISNULL( @c_field21,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field22>', RTRIM( ISNULL( @c_field22,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field23>', RTRIM( ISNULL( @c_field23,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field24>', RTRIM( ISNULL( @c_field24,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field25>', RTRIM( ISNULL( @c_field25,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field26>', RTRIM( ISNULL( @c_field26,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field27>', RTRIM( ISNULL( @c_field27,''))) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field28>', RTRIM( ISNULL( @c_field28,''))) 
 
  
   SET @c_ZPLCode = @c_PrnTemplate  
 
   INSERT INTO CARTONTRACK (LabelNo, CarrierName, KeyName, TrackingNo, printdata,UDF03)  
    VALUES (@c_Param01, 'Internal', @c_Param04, @c_trackingNo, @c_ZPLCode,@c_field11)       --CS01  
   --VALUES (@c_Param02, 'Internal', @c_Param04, (@c_Param02+@c_Param03), @c_ZPLCode)  
  
    UPDATE ORDERS WITH (ROWLOCK)  
    SET  RTNTrackingNo = @c_field11,--@c_orderkey,    --CS01  
         TrafficCop = NULL  
    WHERE Orderkey = @c_Orderkey AND ISNULL(RTNTrackingNo,'') = ''  
  
    IF @@ERROR <> 0  
    BEGIN  
          SELECT @n_Continue = 3  
          SELECT @n_Err = 84032  
          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Trackingno Failed. (isp_GENZPL05)'  
    END  

  ----CS01 S
  --IF @c_OpenPLT = 'Y'
  --BEGIN
  --UPDATE PALLETDETAIL WITH (ROWLOCK)  
 --   SET  userdefine05 = @c_PLTDETUDF05,   --CS01  
 --        TrafficCop = NULL  
 --   WHERE storerkey = @c_Param02
 --   AND   userdefine03= @c_Param03
  --AND PalletKey = @c_Param01
   
  
 --   IF @@ERROR <> 0  
 --   BEGIN  
 --         SELECT @n_Continue = 3  
 --         SELECT @n_Err = 84032  
 --         SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PALLETDETAIL Table userdefine05 Failed. (isp_GENZPL05)'  
 --   END  

  --END

  --CS01 E

Quit_SP:  
  
IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
   ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GenZPL_interface'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
      BEGIN  
         SELECT @b_success = 1  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
         RETURN  
      END  
  
end


GO